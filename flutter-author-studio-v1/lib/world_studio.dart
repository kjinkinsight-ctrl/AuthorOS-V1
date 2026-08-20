import 'dart:convert';

import 'package:flutter/material.dart';

import 'core/built_in_record_types.dart';
import 'core/connected_domain.dart';
import 'core/record_service.dart';
import 'core/story_codex_domain.dart';
import 'persistence/authoros_database.dart';
import 'release_destinations.dart';

enum WorldFieldKind { text, longText, number, toggle, list, reference }

enum WorldCanonStatus { canon, draft, research, authorNotes, nonCanon }

class WorldFieldDefinition {
  const WorldFieldDefinition({
    required this.key,
    required this.label,
    required this.section,
    this.kind = WorldFieldKind.text,
    this.required = false,
    this.defaultValue,
  });

  final String key;
  final String label;
  final String section;
  final WorldFieldKind kind;
  final bool required;
  final Object? defaultValue;
}

class WorldRecordTemplate {
  const WorldRecordTemplate({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    this.parentId,
    this.fields = const [],
    this.suggestedRelationships = const [],
  });

  final String id;
  final String label;
  final String category;
  final String icon;
  final String? parentId;
  final List<WorldFieldDefinition> fields;
  final List<String> suggestedRelationships;
}

class ResolvedWorldTemplate {
  const ResolvedWorldTemplate({
    required this.template,
    required this.fields,
    required this.suggestedRelationships,
  });

  final WorldRecordTemplate template;
  final List<WorldFieldDefinition> fields;
  final List<String> suggestedRelationships;
}

class WorldTemplateRegistry {
  WorldTemplateRegistry(
      {Iterable<WorldRecordTemplate> customTemplates = const []})
      : _templates = {
          for (final template in [...builtInTemplates, ...customTemplates])
            template.id: template,
        } {
    final expectedCount = builtInTemplates.length + customTemplates.length;
    if (_templates.length != expectedCount) {
      throw ArgumentError('World template ids must be unique.');
    }
    for (final template in _templates.values) {
      resolve(template.id);
    }
  }

  final Map<String, WorldRecordTemplate> _templates;

  List<WorldRecordTemplate> get templates => _templates.values.toList()
    ..sort((left, right) => left.label.compareTo(right.label));

  ResolvedWorldTemplate resolve(String id) {
    final lineage = <WorldRecordTemplate>[];
    final visited = <String>{};
    WorldRecordTemplate? current = _templates[id];
    if (current == null) {
      throw ArgumentError.value(id, 'id', 'Unknown world template.');
    }
    while (current != null) {
      if (!visited.add(current.id)) {
        throw StateError('World template inheritance contains a cycle.');
      }
      lineage.add(current);
      final parentId = current.parentId;
      if (parentId == null) {
        break;
      }
      current = _templates[parentId];
      if (current == null) {
        throw StateError('World template $id has unknown parent $parentId.');
      }
    }

    final fields = <String, WorldFieldDefinition>{};
    final relationships = <String>{};
    for (final template in lineage.reversed) {
      for (final field in template.fields) {
        fields[field.key] = field;
      }
      relationships.addAll(template.suggestedRelationships);
    }
    return ResolvedWorldTemplate(
      template: lineage.first,
      fields: fields.values.toList(),
      suggestedRelationships: relationships.toList(),
    );
  }

  String canonicalRecordTypeId(String id) {
    final recordTypes = BuiltInRecordTypes.registry();
    String? currentId = id;
    while (currentId != null) {
      final candidate = _codexTypeId(currentId);
      try {
        recordTypes.resolve(candidate);
        return candidate;
      } on StateError {
        currentId = _templates[currentId]?.parentId;
      }
    }
    return 'custom-entry';
  }

  static final List<WorldRecordTemplate> builtInTemplates = _buildTemplates();
}

class WorldRecordDraft {
  const WorldRecordDraft({
    required this.id,
    required this.title,
    required this.templateId,
    this.fields = const {},
    this.customFields = const {},
    this.tags = const [],
    this.canonStatus = WorldCanonStatus.canon,
    this.archived = false,
  });

  final String id;
  final String title;
  final String templateId;
  final Map<String, Object?> fields;
  final Map<String, Object?> customFields;
  final List<String> tags;
  final WorldCanonStatus canonStatus;
  final bool archived;
}

class WorldStudioService {
  WorldStudioService({
    required this.scopeId,
    required this.repository,
    required this.templates,
  }) : recordService = RecordService(
          projectId: scopeId,
          repository: repository,
        );

  static const legacyRecordTypeId = 'worldRecord';
  static const templateField = '_world.templateId';
  static const canonStatusField = '_world.canonStatus';
  static const customFieldsField = '_world.customFields';
  static const categoryField = '_world.categoryId';

  final String scopeId;
  final DriftConnectedDomainRepository repository;
  final WorldTemplateRegistry templates;
  final RecordService recordService;

  Future<List<AuthorRecord>> loadRecords() async {
    final records = await repository.recordsByScope(scopeId);
    return records.where((record) {
      if (record.typeId == legacyRecordTypeId) return true;
      final templateId = _canonicalTemplateId(record.typeId);
      return templates.templates.any((template) => template.id == templateId);
    }).toList();
  }

  Future<AuthorRecord?> recordById(String id) => repository.recordById(id);

  Future<List<RecordLink>> connections(String recordId) =>
      repository.backlinks(recordId);

  Future<AuthorRecord> save(
    WorldRecordDraft draft, {
    Iterable<RecordLink> links = const [],
    DateTime? timestamp,
  }) async {
    final title = draft.title.trim();
    if (draft.id.trim().isEmpty || title.isEmpty) {
      throw ArgumentError('World record id and title are required.');
    }
    final resolved = templates.resolve(draft.templateId);
    for (final field in resolved.fields.where((field) => field.required)) {
      final value = draft.fields[field.key] ?? field.defaultValue;
      if (value == null || value.toString().trim().isEmpty) {
        throw ArgumentError('${field.label} is required.');
      }
    }

    final existing = await repository.recordById(draft.id);
    if (existing != null && existing.scopeId != scopeId) {
      throw StateError(
          'Record ${draft.id} belongs to another domain or scope.');
    }
    if (existing != null &&
        existing.typeId != legacyRecordTypeId &&
        (existing.fields[templateField] as String? ??
                _canonicalTemplateId(existing.typeId)) !=
            draft.templateId) {
      throw StateError('Record ${draft.id} uses another canonical type.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final defaults = <String, Object?>{
      for (final field in resolved.fields)
        if (field.defaultValue != null) field.key: field.defaultValue,
    };
    final record = AuthorRecord(
      id: draft.id,
      typeId: templates.canonicalRecordTypeId(draft.templateId),
      scopeType: RecordScopeType.project,
      scopeId: scopeId,
      projectId: scopeId,
      canonStatus: _sharedCanonStatus(draft.canonStatus),
      title: title,
      status: draft.archived
          ? AuthorRecordStatus.archived
          : AuthorRecordStatus.active,
      schemaVersion: 1,
      revision: (existing?.revision ?? 0) + 1,
      fields: {
        ...defaults,
        ...draft.fields,
        templateField: draft.templateId,
        canonStatusField: draft.canonStatus.name,
        customFieldsField: draft.customFields,
        categoryField: resolved.template.category,
        CodexFields.templateId:
            templates.canonicalRecordTypeId(draft.templateId),
        CodexFields.categoryId:
            _codexCategoryFor(resolved.template.category, draft.templateId),
        CodexFields.projectId: scopeId,
        CodexFields.canonStatus: _codexCanonStatus(draft.canonStatus),
      },
      tags: draft.tags,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      extensionData: {
        ...?existing?.extensionData,
        'worldStudio': true,
      },
    );
    final linkList = links.toList();
    if (existing?.typeId == legacyRecordTypeId) {
      await repository.putRecordsAndLinks(records: [record], links: linkList);
      return record;
    }
    return existing == null
        ? recordService.createRecord(record, links: linkList)
        : recordService.updateRecord(record, links: linkList);
  }

  RecordLink link({
    required String sourceId,
    required String targetId,
    required String typeId,
    String label = '',
    RecordLinkDirection direction = RecordLinkDirection.directed,
    DateTime? timestamp,
  }) {
    final now = (timestamp ?? DateTime.now()).toUtc();
    final identity = base64Url
        .encode(utf8.encode('$scopeId|$sourceId|$typeId|$targetId'))
        .replaceAll('=', '');
    return RecordLink(
      id: 'world-link-$identity',
      sourceId: sourceId,
      targetId: targetId,
      typeId: typeId,
      scopeId: scopeId,
      direction: direction,
      label: label,
      createdAt: now,
      updatedAt: now,
    );
  }
}

List<WorldRecordTemplate> _buildTemplates() {
  const identity = [
    WorldFieldDefinition(
      key: 'identity.description',
      label: 'Description',
      section: 'Identity',
      kind: WorldFieldKind.longText,
    ),
    WorldFieldDefinition(
      key: 'identity.aliases',
      label: 'Aliases',
      section: 'Identity',
      kind: WorldFieldKind.list,
    ),
    WorldFieldDefinition(
      key: 'notes.canon',
      label: 'Canon notes',
      section: 'Notes',
      kind: WorldFieldKind.longText,
    ),
    WorldFieldDefinition(
      key: 'notes.research',
      label: 'Research',
      section: 'Notes',
      kind: WorldFieldKind.longText,
    ),
  ];
  final templates = <WorldRecordTemplate>[
    const WorldRecordTemplate(
      id: 'world',
      label: 'World',
      category: 'World',
      icon: 'public',
      fields: [
        ...identity,
        WorldFieldDefinition(
            key: 'world.genre', label: 'Genre', section: 'Overview'),
        WorldFieldDefinition(
            key: 'world.population',
            label: 'Population',
            section: 'Overview',
            kind: WorldFieldKind.number),
        WorldFieldDefinition(
            key: 'world.rules',
            label: 'World rules',
            section: 'Systems',
            kind: WorldFieldKind.list),
      ],
      suggestedRelationships: ['contains', 'partOf', 'alternateOf'],
    ),
    const WorldRecordTemplate(
        id: 'planet',
        label: 'Planet',
        category: 'World',
        icon: 'language',
        parentId: 'world'),
    const WorldRecordTemplate(
        id: 'realm',
        label: 'Realm',
        category: 'World',
        icon: 'auto_awesome',
        parentId: 'world'),
    const WorldRecordTemplate(
        id: 'dimension',
        label: 'Dimension',
        category: 'World',
        icon: 'layers',
        parentId: 'world'),
    const WorldRecordTemplate(
      id: 'location',
      label: 'Location',
      category: 'Geography',
      icon: 'place',
      fields: [
        ...identity,
        WorldFieldDefinition(
            key: 'location.climate', label: 'Climate', section: 'Geography'),
        WorldFieldDefinition(
            key: 'location.terrain', label: 'Terrain', section: 'Geography'),
        WorldFieldDefinition(
            key: 'location.population',
            label: 'Population',
            section: 'People',
            kind: WorldFieldKind.number),
        WorldFieldDefinition(
            key: 'location.architecture',
            label: 'Architecture',
            section: 'Culture',
            kind: WorldFieldKind.longText),
        WorldFieldDefinition(
            key: 'location.coordinates',
            label: 'Map coordinates',
            section: 'Map'),
        WorldFieldDefinition(
            key: 'location.history',
            label: 'History',
            section: 'History',
            kind: WorldFieldKind.longText),
      ],
      suggestedRelationships: [
        'locatedIn',
        'borders',
        'controlledBy',
        'appearsIn'
      ],
    ),
    const WorldRecordTemplate(
      id: 'organisation',
      label: 'Organisation',
      category: 'Society',
      icon: 'groups',
      fields: [
        ...identity,
        WorldFieldDefinition(
            key: 'organisation.purpose',
            label: 'Purpose',
            section: 'Identity',
            kind: WorldFieldKind.longText),
        WorldFieldDefinition(
            key: 'organisation.goals',
            label: 'Goals',
            section: 'Identity',
            kind: WorldFieldKind.list),
        WorldFieldDefinition(
            key: 'organisation.ranks',
            label: 'Ranks',
            section: 'Structure',
            kind: WorldFieldKind.list),
        WorldFieldDefinition(
            key: 'organisation.rules',
            label: 'Rules',
            section: 'Structure',
            kind: WorldFieldKind.list),
        WorldFieldDefinition(
            key: 'organisation.secrets',
            label: 'Secrets',
            section: 'Notes',
            kind: WorldFieldKind.longText),
      ],
      suggestedRelationships: ['memberOf', 'controls', 'alliedWith', 'opposes'],
    ),
    const WorldRecordTemplate(
        id: 'faction',
        label: 'Faction',
        category: 'Society',
        icon: 'shield',
        parentId: 'organisation'),
    const WorldRecordTemplate(
      id: 'culture',
      label: 'Culture',
      category: 'Society',
      icon: 'diversity_3',
      fields: [
        ...identity,
        WorldFieldDefinition(
            key: 'culture.values',
            label: 'Values',
            section: 'Beliefs',
            kind: WorldFieldKind.list),
        WorldFieldDefinition(
            key: 'culture.traditions',
            label: 'Traditions',
            section: 'Customs',
            kind: WorldFieldKind.list),
        WorldFieldDefinition(
            key: 'culture.taboos',
            label: 'Taboos',
            section: 'Customs',
            kind: WorldFieldKind.list)
      ],
      suggestedRelationships: ['originatedIn', 'speaks', 'worships'],
    ),
    const WorldRecordTemplate(
        id: 'religion',
        label: 'Religion',
        category: 'Society',
        icon: 'temple_buddhist',
        fields: [
          ...identity,
          WorldFieldDefinition(
              key: 'religion.beliefs',
              label: 'Beliefs',
              section: 'Beliefs',
              kind: WorldFieldKind.list),
          WorldFieldDefinition(
              key: 'religion.rituals',
              label: 'Rituals',
              section: 'Practice',
              kind: WorldFieldKind.list),
          WorldFieldDefinition(
              key: 'religion.afterlife',
              label: 'Afterlife',
              section: 'Beliefs',
              kind: WorldFieldKind.longText)
        ],
        suggestedRelationships: [
          'worshippedBy',
          'contains',
          'originatedIn'
        ]),
    const WorldRecordTemplate(
        id: 'language',
        label: 'Language',
        category: 'Society',
        icon: 'translate',
        fields: [
          ...identity,
          WorldFieldDefinition(
              key: 'language.script',
              label: 'Writing system',
              section: 'Language'),
          WorldFieldDefinition(
              key: 'language.dialects',
              label: 'Dialects',
              section: 'Language',
              kind: WorldFieldKind.list)
        ],
        suggestedRelationships: [
          'spokenBy',
          'originatedIn',
          'derivedFrom'
        ]),
    const WorldRecordTemplate(
        id: 'species',
        label: 'Species',
        category: 'Life',
        icon: 'genetics',
        fields: [
          ...identity,
          WorldFieldDefinition(
              key: 'species.biology',
              label: 'Biology',
              section: 'Biology',
              kind: WorldFieldKind.longText),
          WorldFieldDefinition(
              key: 'species.lifespan', label: 'Lifespan', section: 'Biology'),
          WorldFieldDefinition(
              key: 'species.abilities',
              label: 'Abilities',
              section: 'Biology',
              kind: WorldFieldKind.list)
        ],
        suggestedRelationships: [
          'livesIn',
          'speaks',
          'partOf'
        ]),
    const WorldRecordTemplate(
        id: 'creature',
        label: 'Creature',
        category: 'Life',
        icon: 'pets',
        parentId: 'species',
        fields: [
          WorldFieldDefinition(
              key: 'creature.habitat', label: 'Habitat', section: 'Ecology'),
          WorldFieldDefinition(
              key: 'creature.diet', label: 'Diet', section: 'Ecology'),
          WorldFieldDefinition(
              key: 'creature.threatLevel',
              label: 'Threat level',
              section: 'Ecology')
        ]),
    const WorldRecordTemplate(
        id: 'magicSystem',
        label: 'Magic System',
        category: 'Systems',
        icon: 'auto_fix_high',
        fields: [
          ...identity,
          WorldFieldDefinition(
              key: 'magic.source', label: 'Source', section: 'Rules'),
          WorldFieldDefinition(
              key: 'magic.costs',
              label: 'Costs',
              section: 'Rules',
              kind: WorldFieldKind.list),
          WorldFieldDefinition(
              key: 'magic.limitations',
              label: 'Limitations',
              section: 'Rules',
              kind: WorldFieldKind.list),
          WorldFieldDefinition(
              key: 'magic.risks',
              label: 'Risks',
              section: 'Rules',
              kind: WorldFieldKind.list)
        ],
        suggestedRelationships: [
          'contains',
          'usedBy',
          'originatedIn'
        ]),
    const WorldRecordTemplate(
        id: 'magicRule',
        label: 'Magic Rule',
        category: 'Systems',
        icon: 'rule',
        parentId: 'magicSystem',
        fields: [
          WorldFieldDefinition(
              key: 'rule.requirements',
              label: 'Requirements',
              section: 'Rule',
              kind: WorldFieldKind.list),
          WorldFieldDefinition(
              key: 'rule.exceptions',
              label: 'Exceptions',
              section: 'Rule',
              kind: WorldFieldKind.list)
        ]),
    const WorldRecordTemplate(
        id: 'technology',
        label: 'Technology',
        category: 'Systems',
        icon: 'memory',
        fields: [
          ...identity,
          WorldFieldDefinition(
              key: 'technology.capabilities',
              label: 'Capabilities',
              section: 'Operation',
              kind: WorldFieldKind.list),
          WorldFieldDefinition(
              key: 'technology.limitations',
              label: 'Limitations',
              section: 'Operation',
              kind: WorldFieldKind.list),
          WorldFieldDefinition(
              key: 'technology.energySource',
              label: 'Energy source',
              section: 'Operation')
        ],
        suggestedRelationships: [
          'createdBy',
          'usedBy',
          'requires'
        ]),
    const WorldRecordTemplate(
        id: 'government',
        label: 'Government',
        category: 'Politics',
        icon: 'account_balance',
        fields: [
          ...identity,
          WorldFieldDefinition(
              key: 'government.type',
              label: 'Government type',
              section: 'Structure'),
          WorldFieldDefinition(
              key: 'government.succession',
              label: 'Succession',
              section: 'Structure',
              kind: WorldFieldKind.longText),
          WorldFieldDefinition(
              key: 'government.laws',
              label: 'Laws',
              section: 'Law',
              kind: WorldFieldKind.list)
        ],
        suggestedRelationships: [
          'rules',
          'ledBy',
          'alliedWith',
          'atWarWith'
        ]),
    const WorldRecordTemplate(
        id: 'currency',
        label: 'Currency',
        category: 'Economy',
        icon: 'payments',
        fields: [
          ...identity,
          WorldFieldDefinition(
              key: 'currency.denominations',
              label: 'Denominations',
              section: 'Economy',
              kind: WorldFieldKind.list),
          WorldFieldDefinition(
              key: 'currency.value', label: 'Value', section: 'Economy')
        ],
        suggestedRelationships: [
          'usedBy',
          'issuedBy'
        ]),
    const WorldRecordTemplate(
        id: 'resource',
        label: 'Resource',
        category: 'Economy',
        icon: 'inventory_2',
        fields: [
          ...identity,
          WorldFieldDefinition(
              key: 'resource.rarity', label: 'Rarity', section: 'Economy'),
          WorldFieldDefinition(
              key: 'resource.uses',
              label: 'Uses',
              section: 'Economy',
              kind: WorldFieldKind.list),
          WorldFieldDefinition(
              key: 'resource.production',
              label: 'Production',
              section: 'Economy',
              kind: WorldFieldKind.longText)
        ],
        suggestedRelationships: [
          'producedBy',
          'ownedBy',
          'tradedWith'
        ]),
    const WorldRecordTemplate(
        id: 'historicalEvent',
        label: 'Historical Event',
        category: 'History',
        icon: 'history_edu',
        fields: [
          ...identity,
          WorldFieldDefinition(
              key: 'event.date', label: 'Date', section: 'Timeline'),
          WorldFieldDefinition(
              key: 'event.causes',
              label: 'Causes',
              section: 'History',
              kind: WorldFieldKind.list),
          WorldFieldDefinition(
              key: 'event.consequences',
              label: 'Consequences',
              section: 'History',
              kind: WorldFieldKind.list)
        ],
        suggestedRelationships: [
          'occurredIn',
          'involved',
          'partOf'
        ]),
    const WorldRecordTemplate(
        id: 'era',
        label: 'Era',
        category: 'History',
        icon: 'hourglass_bottom',
        fields: [
          ...identity,
          WorldFieldDefinition(
              key: 'era.start', label: 'Start', section: 'Timeline'),
          WorldFieldDefinition(
              key: 'era.end', label: 'End', section: 'Timeline')
        ],
        suggestedRelationships: [
          'contains',
          'followedBy'
        ]),
    const WorldRecordTemplate(
        id: 'item',
        label: 'Item',
        category: 'Objects',
        icon: 'category',
        fields: [
          ...identity,
          WorldFieldDefinition(
              key: 'item.origin', label: 'Origin', section: 'History'),
          WorldFieldDefinition(
              key: 'item.properties',
              label: 'Properties',
              section: 'Details',
              kind: WorldFieldKind.list),
          WorldFieldDefinition(
              key: 'item.value', label: 'Value', section: 'Details')
        ],
        suggestedRelationships: [
          'ownedBy',
          'createdBy',
          'locatedIn',
          'appearsIn'
        ]),
    const WorldRecordTemplate(
        id: 'artefact',
        label: 'Artefact',
        category: 'Objects',
        icon: 'diamond',
        parentId: 'item'),
    const WorldRecordTemplate(
        id: 'custom',
        label: 'Custom',
        category: 'Custom',
        icon: 'tune',
        fields: identity),
  ];

  const locationTypes = <String, String>{
    'continent': 'Continent',
    'country': 'Country',
    'kingdom': 'Kingdom',
    'empire': 'Empire',
    'republic': 'Republic',
    'state': 'State',
    'province': 'Province',
    'region': 'Region',
    'territory': 'Territory',
    'city': 'City',
    'town': 'Town',
    'village': 'Village',
    'district': 'District',
    'neighbourhood': 'Neighbourhood',
    'street': 'Street',
    'building': 'Building',
    'house': 'House',
    'castle': 'Castle',
    'palace': 'Palace',
    'fortress': 'Fortress',
    'temple': 'Temple',
    'church': 'Church',
    'shrine': 'Shrine',
    'school': 'School',
    'university': 'University',
    'library': 'Library',
    'governmentBuilding': 'Government Building',
    'shop': 'Shop',
    'tavern': 'Tavern',
    'inn': 'Inn',
    'prison': 'Prison',
    'hospital': 'Hospital',
    'militaryBase': 'Military Base',
    'port': 'Port',
    'harbour': 'Harbour',
    'airport': 'Airport',
    'trainStation': 'Train Station',
    'ruins': 'Ruins',
    'dungeon': 'Dungeon',
    'cave': 'Cave',
    'forest': 'Forest',
    'mountain': 'Mountain',
    'river': 'River',
    'lake': 'Lake',
    'ocean': 'Ocean',
    'island': 'Island',
    'desert': 'Desert',
    'swamp': 'Swamp',
    'valley': 'Valley',
    'battlefield': 'Battlefield',
    'graveyard': 'Graveyard',
    'landmark': 'Landmark',
    'secretLocation': 'Secret Location',
    'customLocation': 'Custom Location',
  };
  templates.addAll(locationTypes.entries.map((entry) => WorldRecordTemplate(
        id: entry.key,
        label: entry.value,
        category: 'Geography',
        icon: 'place',
        parentId: 'location',
      )));
  return templates;
}

class WorldStudioWorkspace extends StatefulWidget {
  const WorldStudioWorkspace({
    super.key,
    required this.projectId,
    this.repository,
    this.templates,
  });

  final String projectId;
  final DriftConnectedDomainRepository? repository;
  final WorldTemplateRegistry? templates;

  @override
  State<WorldStudioWorkspace> createState() => _WorldStudioWorkspaceState();
}

class _WorldStudioWorkspaceState extends State<WorldStudioWorkspace> {
  String view = 'world';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String>(
              key: const Key('world-workspace-view-selector'),
              segments: const [
                ButtonSegment(
                  value: 'world',
                  icon: Icon(Icons.public_outlined),
                  label: Text('World database'),
                ),
                ButtonSegment(
                  value: 'codex',
                  icon: Icon(Icons.menu_book_outlined),
                  label: Text('Codex reference'),
                ),
              ],
              selected: {view},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => view = selection.first),
            ),
          ),
          const SizedBox(height: 16),
          if (view == 'world')
            WorldStudioView(
              projectId: widget.projectId,
              repository: widget.repository,
              templates: widget.templates,
            )
          else
            StoryCodexView(
              projectId: widget.projectId,
              repository: widget.repository,
            ),
        ],
      );
}

class WorldStudioView extends StatefulWidget {
  const WorldStudioView({
    super.key,
    required this.projectId,
    this.repository,
    this.templates,
  });

  final String projectId;
  final DriftConnectedDomainRepository? repository;
  final WorldTemplateRegistry? templates;

  @override
  State<WorldStudioView> createState() => _WorldStudioViewState();
}

class _WorldStudioViewState extends State<WorldStudioView> {
  final searchController = TextEditingController();
  late final WorldTemplateRegistry templates;
  late final WorldStudioService studio;
  List<AuthorRecord> records = [];
  bool loading = true;
  String category = 'All';

  @override
  void initState() {
    super.initState();
    templates = widget.templates ?? WorldTemplateRegistry();
    studio = WorldStudioService(
      scopeId: widget.projectId,
      repository: widget.repository ?? authorOsRepository,
      templates: templates,
    );
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await studio.loadRecords();
    if (!mounted) return;
    setState(() {
      records = loaded;
      loading = false;
    });
  }

  Future<void> _edit([AuthorRecord? existing]) async {
    final draft = await showDialog<WorldRecordDraft>(
      context: context,
      builder: (context) => _WorldRecordEditorDialog(
        templates: templates,
        existing: existing,
      ),
    );
    if (draft == null) return;
    await studio.save(draft);
    await _load();
  }

  Future<void> _toggleArchive(AuthorRecord record) async {
    await studio.save(
      WorldRecordDraft(
        id: record.id,
        title: record.title,
        templateId: _templateId(record),
        fields: _contentFields(record),
        customFields: _customFields(record),
        tags: record.tags,
        canonStatus: _canonStatus(record),
        archived: record.status != AuthorRecordStatus.archived,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final query = searchController.text.trim().toLowerCase();
    final visible = records.where((record) {
      final template = templates.resolve(_templateId(record)).template;
      if (category != 'All' && template.category != category) return false;
      if (query.isEmpty) return true;
      return [
        record.title,
        template.label,
        ...record.tags,
        ...record.fields.values,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    final categories = templates.templates.map((item) => item.category).toSet()
      ..remove('Custom');

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'World Studio',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Build the places, societies, systems, and history behind the story.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const Key('add-world-record-button'),
                onPressed: () => _edit(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New record'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _WorldOverview(records: records, templates: templates),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final search = TextField(
              key: const Key('world-search-field'),
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Search world records',
              ),
            );
            final filter = DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                'All',
                ...categories.toList()..sort(),
              ]
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) => setState(() => category = value ?? 'All'),
            );
            if (constraints.maxWidth < 640) {
              return Column(
                  children: [search, const SizedBox(height: 10), filter]);
            }
            return Row(children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              SizedBox(width: 210, child: filter)
            ]);
          }),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            _WorldEmptyState(
                hasRecords: records.isNotEmpty, onAdd: () => _edit())
          else
            LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 1100
                  ? 3
                  : width >= 680
                      ? 2
                      : 1;
              final itemWidth = (width - ((columns - 1) * 12)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: visible
                    .map((record) => SizedBox(
                          width: itemWidth,
                          child: _WorldRecordTile(
                            record: record,
                            template:
                                templates.resolve(_templateId(record)).template,
                            onEdit: () => _edit(record),
                            onArchive: () => _toggleArchive(record),
                          ),
                        ))
                    .toList(),
              );
            }),
        ],
      ),
    );
  }
}

class _WorldOverview extends StatelessWidget {
  const _WorldOverview({required this.records, required this.templates});

  final List<AuthorRecord> records;
  final WorldTemplateRegistry templates;

  @override
  Widget build(BuildContext context) {
    int count(String category) => records
        .where((record) =>
            templates.resolve(_templateId(record)).template.category ==
            category)
        .length;
    final metrics = [
      ('Records', records.length, Icons.hub_outlined),
      ('Geography', count('Geography'), Icons.map_outlined),
      ('Societies', count('Society'), Icons.groups_outlined),
      ('Systems', count('Systems'), Icons.auto_awesome_outlined),
      ('History', count('History'), Icons.history_edu_outlined),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: metrics
          .map((metric) => Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(children: [
                  Icon(metric.$3, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${metric.$2}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          Text(metric.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                ]),
              ))
          .toList(),
    );
  }
}

class _WorldRecordTile extends StatelessWidget {
  const _WorldRecordTile({
    required this.record,
    required this.template,
    required this.onEdit,
    required this.onArchive,
  });

  final AuthorRecord record;
  final WorldRecordTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final description = record.fields['identity.description']?.toString() ?? '';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_worldIcon(template.icon), size: 22),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800))),
                PopupMenuButton<String>(
                  tooltip: 'World record actions',
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onArchive(),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit record')),
                    PopupMenuItem(
                        value: 'archive',
                        child: Text(record.status == AuthorRecordStatus.archived
                            ? 'Restore'
                            : 'Archive')),
                  ],
                ),
              ]),
              Text('${template.label} · ${_canonStatus(record).name}',
                  style: Theme.of(context).textTheme.bodySmall),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (record.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: record.tags
                        .take(4)
                        .map((tag) => Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact))
                        .toList()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldEmptyState extends StatelessWidget {
  const _WorldEmptyState({required this.hasRecords, required this.onAdd});

  final bool hasRecords;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          const Icon(Icons.public_outlined, size: 42),
          const SizedBox(height: 12),
          Text(
              hasRecords
                  ? 'No records match these filters.'
                  : 'This world is ready for its first record.',
              style: Theme.of(context).textTheme.titleMedium),
          if (!hasRecords) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create world record')),
          ],
        ]),
      );
}

class _WorldRecordEditorDialog extends StatefulWidget {
  const _WorldRecordEditorDialog({required this.templates, this.existing});

  final WorldTemplateRegistry templates;
  final AuthorRecord? existing;

  @override
  State<_WorldRecordEditorDialog> createState() =>
      _WorldRecordEditorDialogState();
}

class _WorldRecordEditorDialogState extends State<_WorldRecordEditorDialog> {
  late final TextEditingController titleController;
  late final TextEditingController tagsController;
  late final TextEditingController customKeyController;
  late final TextEditingController customValueController;
  final Map<String, TextEditingController> fieldControllers = {};
  late String templateId;
  late WorldCanonStatus canonStatus;
  late Map<String, Object?> customFields;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    titleController = TextEditingController(text: existing?.title ?? '');
    tagsController =
        TextEditingController(text: existing?.tags.join(', ') ?? '');
    customKeyController = TextEditingController();
    customValueController = TextEditingController();
    templateId = existing == null ? 'world' : _templateId(existing);
    canonStatus =
        existing == null ? WorldCanonStatus.canon : _canonStatus(existing);
    customFields = existing == null ? {} : _customFields(existing);
    _prepareControllers(existing?.fields ?? const {});
  }

  void _prepareControllers(Map<String, Object?> values) {
    for (final field in widget.templates.resolve(templateId).fields) {
      fieldControllers.putIfAbsent(
          field.key,
          () => TextEditingController(
                text:
                    _displayFieldValue(values[field.key] ?? field.defaultValue),
              ));
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    tagsController.dispose();
    customKeyController.dispose();
    customValueController.dispose();
    for (final controller in fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (titleController.text.trim().isEmpty) return;
    final definitions = widget.templates.resolve(templateId).fields;
    final fields = <String, Object?>{};
    for (final field in definitions) {
      final value = fieldControllers[field.key]?.text.trim() ?? '';
      if (value.isEmpty) continue;
      fields[field.key] = switch (field.kind) {
        WorldFieldKind.number => num.tryParse(value) ?? value,
        WorldFieldKind.toggle => value.toLowerCase() == 'true',
        WorldFieldKind.list => value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        _ => value,
      };
    }
    Navigator.of(context).pop(WorldRecordDraft(
      id: widget.existing?.id ??
          'world-${DateTime.now().microsecondsSinceEpoch}',
      title: titleController.text.trim(),
      templateId: templateId,
      fields: fields,
      customFields: customFields,
      tags: tagsController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      canonStatus: canonStatus,
      archived: widget.existing?.status == AuthorRecordStatus.archived,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final resolved = widget.templates.resolve(templateId);
    final grouped = <String, List<WorldFieldDefinition>>{};
    for (final field in resolved.fields) {
      grouped.putIfAbsent(field.section, () => []).add(field);
    }
    return AlertDialog(
      title: Text(
          widget.existing == null ? 'New world record' : 'Edit world record'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                  key: const Key('world-record-title-field'),
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('world-record-template-field'),
                value: templateId,
                decoration: const InputDecoration(labelText: 'Template'),
                items: widget.templates.templates
                    .map((template) => DropdownMenuItem(
                        value: template.id,
                        child:
                            Text('${template.label} · ${template.category}')))
                    .toList(),
                onChanged: widget.existing == null
                    ? (value) {
                        if (value == null) return;
                        setState(() {
                          templateId = value;
                          _prepareControllers(const {});
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WorldCanonStatus>(
                value: canonStatus,
                decoration: const InputDecoration(labelText: 'Record status'),
                items: WorldCanonStatus.values
                    .map((status) => DropdownMenuItem(
                        value: status, child: Text(_canonLabel(status))))
                    .toList(),
                onChanged: (value) =>
                    setState(() => canonStatus = value ?? canonStatus),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                      labelText: 'Tags', hintText: 'book1, politics, secret')),
              ...grouped.entries.expand((section) => [
                    const SizedBox(height: 20),
                    Text(section.key,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...section.value.map((field) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: fieldControllers[field.key],
                            minLines:
                                field.kind == WorldFieldKind.longText ? 3 : 1,
                            maxLines:
                                field.kind == WorldFieldKind.longText ? 6 : 1,
                            keyboardType: field.kind == WorldFieldKind.number
                                ? TextInputType.number
                                : TextInputType.text,
                            decoration: InputDecoration(
                                labelText: field.label,
                                hintText: field.kind == WorldFieldKind.list
                                    ? 'Comma-separated values'
                                    : null),
                          ),
                        )),
                  ]),
              const SizedBox(height: 16),
              Text('Custom fields',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              ...customFields.entries.map((entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    subtitle: Text(entry.value.toString()),
                    trailing: IconButton(
                        tooltip: 'Remove custom field',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () =>
                            setState(() => customFields.remove(entry.key))),
                  )),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: customKeyController,
                        decoration:
                            const InputDecoration(labelText: 'Field name'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: customValueController,
                        decoration: const InputDecoration(labelText: 'Value'))),
                IconButton(
                  tooltip: 'Add custom field',
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: () {
                    final key = customKeyController.text.trim();
                    if (key.isEmpty) return;
                    setState(() {
                      customFields[key] = customValueController.text.trim();
                      customKeyController.clear();
                      customValueController.clear();
                    });
                  },
                ),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            key: const Key('save-world-record-button'),
            onPressed: _submit,
            child: const Text('Save record')),
      ],
    );
  }
}

String _templateId(AuthorRecord record) => _canonicalTemplateId(
      record.fields[WorldStudioService.templateField] as String? ??
          record.fields[CodexFields.templateId] as String? ??
          record.typeId,
    );

WorldCanonStatus _canonStatus(AuthorRecord record) {
  final raw = record.fields[WorldStudioService.canonStatusField] ??
      record.fields[CodexFields.canonStatus];
  if (raw == CodexCanonStatus.alternate.name ||
      raw == CodexCanonStatus.deprecated.name) {
    return WorldCanonStatus.nonCanon;
  }
  if (raw == CodexCanonStatus.proposed.name) {
    return WorldCanonStatus.draft;
  }
  return WorldCanonStatus.values
          .where((value) => value.name == raw)
          .firstOrNull ??
      WorldCanonStatus.canon;
}

Map<String, Object?> _customFields(AuthorRecord record) {
  final raw = record.fields[WorldStudioService.customFieldsField];
  return raw is Map
      ? raw.map((key, value) => MapEntry(key.toString(), value))
      : <String, Object?>{};
}

Map<String, Object?> _contentFields(AuthorRecord record) => {
      for (final entry in record.fields.entries)
        if (!entry.key.startsWith('_world.') &&
            !entry.key.startsWith(CodexFields.prefix))
          entry.key: entry.value,
    };

String _canonicalTemplateId(String id) => switch (id) {
      'magic-system' => 'magicSystem',
      'magic-rule' => 'magicRule',
      'historical-event' => 'historicalEvent',
      'custom-entry' => 'custom',
      'place' => 'location',
      'object' => 'item',
      _ => id,
    };

String _codexTypeId(String id) => switch (id) {
      'magicSystem' => 'magic-system',
      'magicRule' => 'magic-rule',
      'historicalEvent' => 'historical-event',
      'custom' => 'custom-entry',
      _ => id,
    };

String _codexCategoryFor(String category, String templateId) =>
    switch (category) {
      'Geography' => 'locations',
      'Society' when templateId == 'religion' => 'religion',
      'Society' when templateId == 'culture' || templateId == 'language' =>
        'culture',
      'Society' => 'factions',
      'Life' => 'creatures',
      'Systems' when templateId == 'technology' => 'technology',
      'Systems' => 'magic',
      'Politics' => 'factions',
      'Economy' when templateId == 'currency' => 'culture',
      'History' => 'history',
      'Objects' => 'items',
      'Custom' => 'custom',
      _ => 'world',
    };

String _codexCanonStatus(WorldCanonStatus status) => switch (status) {
      WorldCanonStatus.canon => CodexCanonStatus.canon.name,
      WorldCanonStatus.draft => CodexCanonStatus.draft.name,
      WorldCanonStatus.research => CodexCanonStatus.draft.name,
      WorldCanonStatus.authorNotes => CodexCanonStatus.draft.name,
      WorldCanonStatus.nonCanon => CodexCanonStatus.nonCanon.name,
    };

CanonStatus _sharedCanonStatus(WorldCanonStatus status) => switch (status) {
      WorldCanonStatus.canon => CanonStatus.canon,
      WorldCanonStatus.draft ||
      WorldCanonStatus.research ||
      WorldCanonStatus.authorNotes =>
        CanonStatus.draft,
      WorldCanonStatus.nonCanon => CanonStatus.nonCanon,
    };

String _displayFieldValue(Object? value) =>
    value is List ? value.join(', ') : value?.toString() ?? '';

String _canonLabel(WorldCanonStatus status) => switch (status) {
      WorldCanonStatus.canon => 'Canon',
      WorldCanonStatus.draft => 'Draft',
      WorldCanonStatus.research => 'Research',
      WorldCanonStatus.authorNotes => 'Author notes',
      WorldCanonStatus.nonCanon => 'Non-canon',
    };

IconData _worldIcon(String name) => switch (name) {
      'place' => Icons.place_outlined,
      'groups' => Icons.groups_outlined,
      'shield' => Icons.shield_outlined,
      'translate' => Icons.translate_rounded,
      'genetics' => Icons.biotech_outlined,
      'pets' => Icons.pets_outlined,
      'auto_fix_high' => Icons.auto_fix_high_outlined,
      'memory' => Icons.memory_outlined,
      'account_balance' => Icons.account_balance_outlined,
      'payments' => Icons.payments_outlined,
      'inventory_2' => Icons.inventory_2_outlined,
      'history_edu' => Icons.history_edu_outlined,
      'diamond' => Icons.diamond_outlined,
      _ => Icons.public_outlined,
    };
