import 'character_record_types.dart';
import 'plot_record_types.dart';
import 'record_types.dart';
import 'research_record_types.dart';
import 'timeline_record_types.dart';
import 'world_record_types.dart';

class BuiltInRecordTypes {
  const BuiltInRecordTypes._();

  static final List<RecordTypeDefinition> definitions = [
    _generalLore,
    CharacterRecordTypes.character,
    ...CharacterRecordTypes.templates,
    ...PlotRecordTypes.definitions,
    ...TimelineRecordTypes.definitions,
    ...ResearchRecordTypes.definitions,
    ...WorldRecordTypes.definitions,
    _faction,
    _culture,
    _religion,
    _magicSystem,
    _historicalEvent,
    _item,
    ..._derivedChildren(const {
      'organisation': ('Organisation', 'factions', 'faction'),
      'house': ('House', 'factions', 'faction'),
      'clan': ('Clan', 'factions', 'faction'),
      'deity': ('Deity', 'religion', 'religion'),
      'magic-ability': ('Magic Ability', 'magic', 'magic-system'),
      'spell': ('Spell', 'magic', 'magic-system'),
      'artefact': ('Artefact', 'items', 'item'),
      'weapon': ('Weapon', 'items', 'item'),
      'armour': ('Armour', 'items', 'item'),
      'clothing': ('Clothing', 'items', 'item'),
      'historical-period': ('Historical Period', 'history', 'historical-event'),
      'era': ('Era', 'history', 'historical-period'),
    }),
    ..._children(const {
      'technology': ('Technology', 'technology'),
      'species': ('Species', 'creatures'),
      'race': ('Race', 'creatures'),
      'creature': ('Creature', 'creatures'),
      'monster': ('Monster', 'creatures'),
      'language': ('Language', 'culture'),
      'currency': ('Currency', 'culture'),
      'resource': ('Resource', 'world'),
      'government': ('Government', 'factions'),
      'political-system': ('Political System', 'factions'),
      'myth': ('Myth', 'lore'),
      'legend': ('Legend', 'lore'),
      'rumour': ('Rumour', 'lore'),
      'folklore': ('Folklore', 'lore'),
      'custom-tradition': ('Custom / Tradition', 'culture'),
      'institution': ('Institution', 'factions'),
      'profession': ('Profession', 'characters'),
      'law': ('Law', 'world'),
      'rule': ('Rule', 'world'),
      'concept': ('Concept', 'lore'),
      'theory': ('Theory', 'lore'),
      'secret': ('Secret', 'plot'),
      'mystery': ('Mystery', 'plot'),
      'clue': ('Clue', 'plot'),
      'plot-thread': ('Plot Thread', 'plot'),
      'theme': ('Theme', 'plot'),
      'symbol': ('Symbol', 'plot'),
      'motif': ('Motif', 'plot'),
      'disease': ('Disease', 'world'),
      'medicine': ('Medicine', 'world'),
      'plant': ('Plant', 'creatures'),
      'animal': ('Animal', 'creatures'),
      'food': ('Food', 'culture'),
      'location-type': ('Location Type', 'locations'),
      'architectural-feature': ('Architectural Feature', 'locations'),
      'organisation-role': ('Organisation Role', 'factions'),
      'occupation': ('Occupation', 'characters'),
      'festival': ('Festival', 'culture'),
      'holiday': ('Holiday', 'culture'),
      'calendar-system': ('Calendar System', 'history'),
      'calendar-event': ('Calendar Event', 'history'),
      'technology-system': ('Technology System', 'technology'),
      'magic-rule': ('Magic Rule', 'magic'),
      'magic-limitation': ('Magic Limitation', 'magic'),
      'world-rule': ('World Rule', 'world'),
      'reference': ('Reference', 'reference'),
      'glossary-term': ('Glossary Term', 'reference'),
      'author-note': ('Author Note', 'reference'),
      'custom-entry': ('Custom Entry', 'custom'),
      'series': ('Series', 'manuscript'),
      'book': ('Book', 'manuscript'),
      'document': ('Document', 'reference'),
      'chapter': ('Chapter', 'manuscript'),
      'scene': ('Scene', 'manuscript'),
      'other-custom-entry': ('Other Custom Entry', 'custom'),
    }),
    _legacyAlias('place', 'Place', 'location', 'places'),
    _legacyAlias('object', 'Object', 'item', 'items'),
    _legacyAlias('lore', 'Lore', 'general-lore', 'lore'),
    _selectableAlias('general', 'General', 'general-lore', 'lore'),
    _selectableAlias('glossary', 'Glossary', 'glossary-term', 'reference'),
    _selectableAlias('custom', 'Custom', 'custom-entry', 'custom'),
  ];

  static RecordTypeRegistry registry({
    Iterable<RecordTypeDefinition> additionalDefinitions = const [],
  }) =>
      RecordTypeRegistry([...definitions, ...additionalDefinitions]);
}

const _generalLore = RecordTypeDefinition(
  id: 'general-lore',
  name: 'Basic Lore',
  description: 'Structured knowledge that does not require a narrower type.',
  icon: 'auto_stories',
  categoryId: 'lore',
  fields: [
    RecordFieldDefinition(
      id: 'name',
      label: 'Name',
      type: RecordFieldType.shortText,
      order: 0,
      extensionData: {'recordProperty': 'title', 'templateOwned': true},
    ),
    RecordFieldDefinition(
      id: 'aliases',
      label: 'Aliases',
      type: RecordFieldType.list,
      order: 1,
      extensionData: {'searchable': true, 'templateOwned': true},
    ),
    RecordFieldDefinition(
      id: 'summary',
      label: 'Summary',
      type: RecordFieldType.longText,
      order: 2,
    ),
    RecordFieldDefinition(
      id: 'description',
      label: 'Description',
      type: RecordFieldType.richText,
      order: 3,
    ),
    RecordFieldDefinition(
      id: 'notes',
      label: 'Notes',
      type: RecordFieldType.longText,
      order: 4,
    ),
    RecordFieldDefinition(
      id: 'knowledgeStatus',
      label: 'Knowledge status',
      type: RecordFieldType.singleChoice,
      order: 5,
      defaultValue: 'Unknown',
      options: [
        'Confirmed',
        'Suspected',
        'Rumoured',
        'False',
        'Unknown',
        'Secret',
        'Revealed',
      ],
      extensionData: {'visibility': 'author', 'templateOwned': true},
    ),
    RecordFieldDefinition(
      id: 'sourceReferences',
      label: 'Source references',
      type: RecordFieldType.list,
      order: 6,
      extensionData: {'stableIds': true, 'templateOwned': true},
    ),
  ],
  sections: [
    RecordTemplateSection(
      id: 'overview',
      title: 'Overview',
      order: 0,
      fieldIds: ['name', 'aliases', 'summary', 'description'],
    ),
    RecordTemplateSection(
      id: 'notes',
      title: 'Notes',
      order: 1,
      fieldIds: ['notes', 'knowledgeStatus', 'sourceReferences'],
      collapsedByDefault: true,
    ),
  ],
  suggestedLinkTypeIds: ['relatedTo', 'mentionedIn'],
  builtIn: true,
  sourcePackId: 'authoros-core',
  permissions: {'editableDefinition': false},
  exportBehavior: {'includeStructuredFields': true},
);

const _world = RecordTypeDefinition(
  id: 'world',
  name: 'World',
  description: 'A canonical world shared with World Studio.',
  icon: 'public',
  categoryId: 'world',
  baseTypeId: 'general-lore',
  fields: [
    RecordFieldDefinition(
      id: 'geography',
      label: 'Geography',
      type: RecordFieldType.longText,
      order: 100,
    ),
    RecordFieldDefinition(
      id: 'politics',
      label: 'Politics',
      type: RecordFieldType.longText,
      order: 101,
    ),
    RecordFieldDefinition(
      id: 'economy',
      label: 'Economy',
      type: RecordFieldType.longText,
      order: 102,
    ),
    RecordFieldDefinition(
      id: 'history',
      label: 'History',
      type: RecordFieldType.longText,
      order: 103,
    ),
  ],
  sections: [
    RecordTemplateSection(
      id: 'worldbuilding',
      title: 'Worldbuilding',
      order: 10,
      fieldIds: ['geography', 'politics', 'economy', 'history'],
    ),
  ],
  suggestedLinkTypeIds: ['contains', 'governedBy'],
  builtIn: true,
  sourcePackId: 'authoros-core',
  permissions: {'editableDefinition': false},
);

final _location = _deepTemplate(
  id: 'location',
  name: 'Location',
  categoryId: 'locations',
  sectionId: 'geography',
  sectionTitle: 'Geography',
  fields: const [
    ('locationType', 'Type', RecordFieldType.shortText),
    ('geography', 'Geography', RecordFieldType.longText),
    ('climate', 'Climate', RecordFieldType.longText),
    ('population', 'Population', RecordFieldType.shortText),
    ('culture', 'Culture', RecordFieldType.recordReference),
    ('government', 'Government', RecordFieldType.recordReference),
    ('economy', 'Economy', RecordFieldType.longText),
    ('history', 'History', RecordFieldType.richText),
    ('importantPeople', 'Important People', RecordFieldType.list),
    ('factions', 'Factions', RecordFieldType.list),
    ('nearbyLocations', 'Nearby Locations', RecordFieldType.list),
    ('secrets', 'Secrets', RecordFieldType.richText),
  ],
  suggestedLinks: const ['locatedIn', 'contains', 'governedBy'],
);

final _faction = _deepTemplate(
  id: 'faction',
  name: 'Faction',
  categoryId: 'factions',
  sectionId: 'factions',
  sectionTitle: 'Faction',
  fields: const [
    ('factionType', 'Type', RecordFieldType.shortText),
    ('purpose', 'Purpose', RecordFieldType.longText),
    ('leadership', 'Leadership', RecordFieldType.list),
    ('members', 'Members', RecordFieldType.list),
    ('hierarchy', 'Hierarchy', RecordFieldType.richText),
    ('territory', 'Territory', RecordFieldType.recordReference),
    ('allies', 'Allies', RecordFieldType.list),
    ('enemies', 'Enemies', RecordFieldType.list),
    ('resources', 'Resources', RecordFieldType.longText),
    ('beliefs', 'Beliefs', RecordFieldType.richText),
    ('history', 'History', RecordFieldType.richText),
    ('secrets', 'Secrets', RecordFieldType.richText),
  ],
  suggestedLinks: const ['memberOf', 'alliedWith', 'enemyOf'],
);

final _culture = _deepTemplate(
  id: 'culture',
  name: 'Culture',
  categoryId: 'culture',
  sectionId: 'culture',
  sectionTitle: 'Culture',
  fields: const [
    ('origin', 'Origin', RecordFieldType.longText),
    ('values', 'Values', RecordFieldType.list),
    ('customs', 'Customs', RecordFieldType.richText),
    ('traditions', 'Traditions', RecordFieldType.richText),
    ('language', 'Language', RecordFieldType.recordReference),
    ('religion', 'Religion', RecordFieldType.recordReference),
    ('clothing', 'Clothing', RecordFieldType.richText),
    ('food', 'Food', RecordFieldType.richText),
    ('art', 'Art', RecordFieldType.richText),
    ('socialStructure', 'Social Structure', RecordFieldType.richText),
    ('familyStructure', 'Family Structure', RecordFieldType.richText),
    ('laws', 'Laws', RecordFieldType.list),
    ('taboos', 'Taboos', RecordFieldType.list),
  ],
  suggestedLinks: const ['associatedWith', 'influences'],
);

final _religion = _deepTemplate(
  id: 'religion',
  name: 'Religion',
  categoryId: 'religion',
  sectionId: 'religion',
  sectionTitle: 'Religion',
  fields: const [
    ('beliefs', 'Beliefs', RecordFieldType.richText),
    ('deities', 'Deities', RecordFieldType.list),
    ('practices', 'Practices', RecordFieldType.richText),
    ('sacredTexts', 'Sacred Texts', RecordFieldType.list),
    ('rituals', 'Rituals', RecordFieldType.richText),
    ('holidays', 'Holidays', RecordFieldType.list),
    ('clergy', 'Clergy', RecordFieldType.richText),
    ('symbols', 'Symbols', RecordFieldType.list),
    ('taboos', 'Taboos', RecordFieldType.list),
    ('history', 'History', RecordFieldType.richText),
  ],
  suggestedLinks: const ['worships', 'associatedWith'],
);

final _magicSystem = _deepTemplate(
  id: 'magic-system',
  name: 'Magic System',
  categoryId: 'magic',
  sectionId: 'magic',
  sectionTitle: 'Magic',
  fields: const [
    ('source', 'Source', RecordFieldType.longText),
    ('rules', 'Rules', RecordFieldType.richText),
    ('limitations', 'Limitations', RecordFieldType.richText),
    ('costs', 'Costs', RecordFieldType.richText),
    ('abilities', 'Abilities', RecordFieldType.list),
    ('users', 'Users', RecordFieldType.list),
    ('risks', 'Risks', RecordFieldType.richText),
    ('exceptions', 'Exceptions', RecordFieldType.richText),
    ('history', 'History', RecordFieldType.richText),
    ('culturalImpact', 'Cultural Impact', RecordFieldType.richText),
    ('politicalImpact', 'Political Impact', RecordFieldType.richText),
  ],
  suggestedLinks: const ['usedBy', 'requires', 'influences'],
);

final _historicalEvent = _deepTemplate(
  id: 'historical-event',
  name: 'Historical Event',
  categoryId: 'history',
  sectionId: 'timeline',
  sectionTitle: 'Timeline',
  fields: const [
    ('date', 'Date', RecordFieldType.date),
    ('period', 'Period', RecordFieldType.recordReference),
    ('location', 'Location', RecordFieldType.locationReference),
    ('participants', 'Participants', RecordFieldType.list),
    ('cause', 'Cause', RecordFieldType.richText),
    ('event', 'Event', RecordFieldType.richText),
    ('consequences', 'Consequences', RecordFieldType.richText),
    ('publicKnowledge', 'Public Knowledge', RecordFieldType.richText),
    ('hiddenTruth', 'Hidden Truth', RecordFieldType.richText),
    ('relatedEvents', 'Related Events', RecordFieldType.list),
  ],
  suggestedLinks: const ['caused', 'resultedIn', 'precedes', 'follows'],
);

final _item = _deepTemplate(
  id: 'item',
  name: 'Item / Artifact',
  categoryId: 'items',
  sectionId: 'items',
  sectionTitle: 'Item',
  fields: const [
    ('itemType', 'Type', RecordFieldType.shortText),
    ('creator', 'Creator', RecordFieldType.recordReference),
    ('owner', 'Owner', RecordFieldType.recordReference),
    ('materials', 'Materials', RecordFieldType.list),
    ('powers', 'Powers', RecordFieldType.richText),
    ('limitations', 'Limitations', RecordFieldType.richText),
    ('history', 'History', RecordFieldType.richText),
    ('currentLocation', 'Current Location', RecordFieldType.locationReference),
    ('knownUsers', 'Known Users', RecordFieldType.list),
    ('secrets', 'Secrets', RecordFieldType.richText),
  ],
  suggestedLinks: const ['createdBy', 'ownedBy', 'usedBy', 'locatedIn'],
);

RecordTypeDefinition _deepTemplate({
  required String id,
  required String name,
  required String categoryId,
  required String sectionId,
  required String sectionTitle,
  required List<(String, String, RecordFieldType)> fields,
  required List<String> suggestedLinks,
}) =>
    RecordTypeDefinition(
      id: id,
      name: name,
      categoryId: categoryId,
      baseTypeId: 'general-lore',
      fields: [
        for (var index = 0; index < fields.length; index++)
          RecordFieldDefinition(
            id: fields[index].$1,
            label: fields[index].$2,
            type: fields[index].$3,
            order: 100 + index,
            extensionData: const {
              'visibility': 'default',
              'templateOwned': true,
            },
          ),
      ],
      sections: [
        RecordTemplateSection(
          id: sectionId,
          title: sectionTitle,
          order: 10,
          fieldIds: fields.map((field) => field.$1).toList(),
        ),
      ],
      suggestedLinkTypeIds: suggestedLinks,
      builtIn: true,
      sourcePackId: 'authoros-core',
      permissions: const {'editableDefinition': false},
      extensionData: const {'codexTemplate': true, 'supportsSimpleMode': true},
    );

Iterable<RecordTypeDefinition> _children(
  Map<String, (String, String)> definitions,
) =>
    definitions.entries.map(
      (entry) => RecordTypeDefinition(
        id: entry.key,
        name: entry.value.$1,
        categoryId: entry.value.$2,
        baseTypeId: 'general-lore',
        fields: const [],
        sections: const [],
        builtIn: true,
        sourcePackId: 'authoros-core',
        permissions: const {'editableDefinition': false},
      ),
    );

Iterable<RecordTypeDefinition> _derivedChildren(
  Map<String, (String, String, String)> definitions,
) =>
    definitions.entries.map(
      (entry) => RecordTypeDefinition(
        id: entry.key,
        name: entry.value.$1,
        categoryId: entry.value.$2,
        baseTypeId: entry.value.$3,
        fields: const [],
        sections: const [],
        builtIn: true,
        sourcePackId: 'authoros-core',
        permissions: const {'editableDefinition': false},
        extensionData: const {'codexTemplate': true},
      ),
    );

RecordTypeDefinition _legacyAlias(
  String id,
  String name,
  String baseTypeId,
  String categoryId,
) =>
    RecordTypeDefinition(
      id: id,
      name: name,
      categoryId: categoryId,
      baseTypeId: baseTypeId,
      fields: const [],
      sections: const [],
      builtIn: true,
      sourcePackId: 'authoros-core',
      permissions: const {'editableDefinition': false},
      extensionData: const {
        'legacyAlias': true,
        'selectableForNewRecords': false,
      },
    );

RecordTypeDefinition _selectableAlias(
  String id,
  String name,
  String baseTypeId,
  String categoryId,
) =>
    RecordTypeDefinition(
      id: id,
      name: name,
      categoryId: categoryId,
      baseTypeId: baseTypeId,
      fields: const [],
      sections: const [],
      builtIn: true,
      sourcePackId: 'authoros-core',
      permissions: const {'editableDefinition': false},
    );
