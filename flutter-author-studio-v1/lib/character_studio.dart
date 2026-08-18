import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding.dart';

const _characterSections = <String>[
  'Overview',
  'Identity',
  'Appearance',
  'Personality',
  'Psychology',
  'History',
  'Goals',
  'Arc',
  'Voice',
  'Relationships',
  'Scenes',
  'Timeline',
  'Locations',
  'Factions',
  'Items',
  'Plot Threads',
  'Notes',
  'Connections',
];

const _characterFieldDefinitions = <_CharacterFieldDefinition>[
  _CharacterFieldDefinition('identity', 'fullName', 'Full name',
      required: true),
  _CharacterFieldDefinition('identity', 'firstName', 'First name'),
  _CharacterFieldDefinition('identity', 'middleName', 'Middle name'),
  _CharacterFieldDefinition('identity', 'lastName', 'Last name'),
  _CharacterFieldDefinition('identity', 'nicknames', 'Nicknames'),
  _CharacterFieldDefinition('identity', 'titles', 'Titles'),
  _CharacterFieldDefinition('identity', 'aliases', 'Aliases'),
  _CharacterFieldDefinition('identity', 'pronouns', 'Pronouns'),
  _CharacterFieldDefinition('identity', 'age', 'Age'),
  _CharacterFieldDefinition('identity', 'dateOfBirth', 'Date of birth'),
  _CharacterFieldDefinition('identity', 'placeOfBirth', 'Place of birth'),
  _CharacterFieldDefinition('identity', 'species', 'Species / race'),
  _CharacterFieldDefinition('identity', 'nationality', 'Nationality / culture'),
  _CharacterFieldDefinition('identity', 'occupation', 'Occupation'),
  _CharacterFieldDefinition('identity', 'affiliations', 'Affiliations'),
  _CharacterFieldDefinition('appearance', 'height', 'Height'),
  _CharacterFieldDefinition('appearance', 'build', 'Build'),
  _CharacterFieldDefinition('appearance', 'bodyType', 'Body type'),
  _CharacterFieldDefinition('appearance', 'hair', 'Hair'),
  _CharacterFieldDefinition('appearance', 'hairColour', 'Hair colour'),
  _CharacterFieldDefinition('appearance', 'eyeColour', 'Eye colour'),
  _CharacterFieldDefinition('appearance', 'skinTone', 'Skin tone'),
  _CharacterFieldDefinition(
      'appearance', 'features', 'Distinguishing features'),
  _CharacterFieldDefinition('appearance', 'scars', 'Scars'),
  _CharacterFieldDefinition('appearance', 'tattoos', 'Tattoos / birthmarks'),
  _CharacterFieldDefinition('appearance', 'clothing', 'Clothing'),
  _CharacterFieldDefinition('appearance', 'accessories', 'Accessories'),
  _CharacterFieldDefinition(
      'appearance', 'carriedItems', 'Weapons / carried items'),
  _CharacterFieldDefinition('appearance', 'notes', 'Appearance notes',
      long: true),
  _CharacterFieldDefinition('personality', 'summary', 'Personality summary',
      long: true),
  _CharacterFieldDefinition('personality', 'coreTraits', 'Core traits'),
  _CharacterFieldDefinition('personality', 'positiveTraits', 'Positive traits'),
  _CharacterFieldDefinition('personality', 'negativeTraits', 'Negative traits'),
  _CharacterFieldDefinition('personality', 'strengths', 'Strengths'),
  _CharacterFieldDefinition('personality', 'weaknesses', 'Weaknesses'),
  _CharacterFieldDefinition('personality', 'habits', 'Habits / mannerisms'),
  _CharacterFieldDefinition('personality', 'quirks', 'Quirks'),
  _CharacterFieldDefinition('personality', 'likes', 'Likes'),
  _CharacterFieldDefinition('personality', 'dislikes', 'Dislikes'),
  _CharacterFieldDefinition(
      'personality', 'values', 'Values / beliefs / morals'),
  _CharacterFieldDefinition('personality', 'temperament', 'Temperament'),
  _CharacterFieldDefinition(
      'personality', 'emotionalTendencies', 'Emotional tendencies'),
  _CharacterFieldDefinition(
      'personality', 'socialBehaviour', 'Social behaviour'),
  _CharacterFieldDefinition('psychology', 'coreDesire', 'Core desire'),
  _CharacterFieldDefinition(
      'psychology', 'primaryMotivation', 'Primary motivation'),
  _CharacterFieldDefinition(
      'psychology', 'secondaryMotivations', 'Secondary motivations'),
  _CharacterFieldDefinition('psychology', 'fears', 'Fears / phobias'),
  _CharacterFieldDefinition('psychology', 'insecurities', 'Insecurities'),
  _CharacterFieldDefinition(
      'psychology', 'internalConflict', 'Internal conflict'),
  _CharacterFieldDefinition(
      'psychology', 'externalConflict', 'External conflict'),
  _CharacterFieldDefinition(
      'psychology', 'emotionalWounds', 'Emotional wounds'),
  _CharacterFieldDefinition('psychology', 'secrets', 'Secrets', long: true),
  _CharacterFieldDefinition('psychology', 'shame', 'Shame / guilt'),
  _CharacterFieldDefinition('psychology', 'needs', 'Needs'),
  _CharacterFieldDefinition('psychology', 'wants', 'Wants'),
  _CharacterFieldDefinition('psychology', 'misbeliefs', 'Misbeliefs'),
  _CharacterFieldDefinition('psychology', 'boundaries', 'Boundaries'),
  _CharacterFieldDefinition('history', 'childhood', 'Childhood', long: true),
  _CharacterFieldDefinition('history', 'familyBackground', 'Family background',
      long: true),
  _CharacterFieldDefinition('history', 'education', 'Education'),
  _CharacterFieldDefinition(
      'history', 'significantEvents', 'Significant events',
      long: true),
  _CharacterFieldDefinition(
      'history', 'previousOccupations', 'Previous occupations'),
  _CharacterFieldDefinition(
      'history', 'importantMemories', 'Important memories',
      long: true),
  _CharacterFieldDefinition('goals', 'primaryGoal', 'Primary goal'),
  _CharacterFieldDefinition('goals', 'secondaryGoals', 'Secondary goals'),
  _CharacterFieldDefinition('goals', 'shortTermGoals', 'Short-term goals'),
  _CharacterFieldDefinition('goals', 'longTermGoals', 'Long-term goals'),
  _CharacterFieldDefinition('goals', 'internalGoal', 'Internal goal'),
  _CharacterFieldDefinition('goals', 'externalGoal', 'External goal'),
  _CharacterFieldDefinition('goals', 'motivation', 'Motivation'),
  _CharacterFieldDefinition('goals', 'obstacles', 'Obstacles'),
  _CharacterFieldDefinition('goals', 'stakes', 'Stakes / consequences'),
  _CharacterFieldDefinition('arc', 'type', 'Arc type'),
  _CharacterFieldDefinition('arc', 'startingState', 'Starting state',
      long: true),
  _CharacterFieldDefinition('arc', 'desiredState', 'Desired state', long: true),
  _CharacterFieldDefinition('arc', 'turningPoints', 'Major turning points',
      long: true),
  _CharacterFieldDefinition('arc', 'internalChanges', 'Internal changes'),
  _CharacterFieldDefinition('arc', 'externalChanges', 'External changes'),
  _CharacterFieldDefinition('arc', 'lessons', 'Lessons / failures / victories'),
  _CharacterFieldDefinition('arc', 'resolution', 'Resolution', long: true),
  _CharacterFieldDefinition('voice', 'description', 'Voice description',
      long: true),
  _CharacterFieldDefinition('voice', 'speechStyle', 'Speech style'),
  _CharacterFieldDefinition('voice', 'vocabulary', 'Vocabulary'),
  _CharacterFieldDefinition('voice', 'formality', 'Formality'),
  _CharacterFieldDefinition('voice', 'accent', 'Accent / dialect notes'),
  _CharacterFieldDefinition('voice', 'sentencePatterns', 'Sentence patterns'),
  _CharacterFieldDefinition('voice', 'expressions', 'Favourite expressions'),
  _CharacterFieldDefinition('voice', 'verbalHabits', 'Verbal habits'),
  _CharacterFieldDefinition('voice', 'neverSay', 'Things they would never say'),
  _CharacterFieldDefinition('voice', 'dialogueExamples', 'Dialogue examples',
      long: true),
  _CharacterFieldDefinition('voice', 'internalVoice', 'Internal voice notes',
      long: true),
  _CharacterFieldDefinition('notes', 'general', 'General notes', long: true),
  _CharacterFieldDefinition('notes', 'research', 'Research notes', long: true),
  _CharacterFieldDefinition('notes', 'revision', 'Revision notes', long: true),
  _CharacterFieldDefinition('notes', 'continuity', 'Continuity notes',
      long: true),
  _CharacterFieldDefinition('notes', 'sceneIdeas', 'Scene ideas', long: true),
  _CharacterFieldDefinition('notes', 'dialogueIdeas', 'Dialogue ideas',
      long: true),
  _CharacterFieldDefinition('notes', 'authorOnly', 'Author-only notes',
      long: true),
];

class _CharacterFieldDefinition {
  const _CharacterFieldDefinition(
    this.section,
    this.key,
    this.label, {
    this.required = false,
    this.long = false,
  });

  final String section;
  final String key;
  final String label;
  final bool required;
  final bool long;

  String get path => '$section.$key';
}

class CharacterStudioRecord {
  const CharacterStudioRecord({
    required this.id,
    required this.template,
    required this.status,
    required this.fields,
    required this.customFields,
    required this.connections,
    this.portraitPath = '',
    this.referenceImages = const [],
    this.schemaVersion = 1,
  });

  final String id;
  final String template;
  final String status;
  final Map<String, String> fields;
  final Map<String, String> customFields;
  final Map<String, List<String>> connections;
  final String portraitPath;
  final List<String> referenceImages;
  final int schemaVersion;

  String get name => fields['identity.fullName']?.trim().isNotEmpty == true
      ? fields['identity.fullName']!.trim()
      : 'Unnamed Character';
  String get role => fields['identity.role'] ?? template;
  bool get isArchived => status == 'Archived';

  CharacterStudioRecord copyWith({
    String? id,
    String? template,
    String? status,
    Map<String, String>? fields,
    Map<String, String>? customFields,
    Map<String, List<String>>? connections,
    String? portraitPath,
    List<String>? referenceImages,
  }) =>
      CharacterStudioRecord(
        id: id ?? this.id,
        template: template ?? this.template,
        status: status ?? this.status,
        fields: fields ?? this.fields,
        customFields: customFields ?? this.customFields,
        connections: connections ?? this.connections,
        portraitPath: portraitPath ?? this.portraitPath,
        referenceImages: referenceImages ?? this.referenceImages,
        schemaVersion: schemaVersion,
      );

  Map<String, Object> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'template': template,
        'status': status,
        'fields': fields,
        'customFields': customFields,
        'connections': connections,
        'portraitPath': portraitPath,
        'referenceImages': referenceImages,
      };

  factory CharacterStudioRecord.fromJson(Map<String, dynamic> json) {
    final rawConnections = Map<String, dynamic>.from(
      json['connections'] as Map? ?? const {},
    );
    return CharacterStudioRecord(
      id: json['id'] as String? ?? '',
      template: json['template'] as String? ?? 'Standard Character',
      status: json['status'] as String? ?? 'Active',
      fields: Map<String, String>.from(json['fields'] as Map? ?? const {}),
      customFields:
          Map<String, String>.from(json['customFields'] as Map? ?? const {}),
      connections: {
        for (final entry in rawConnections.entries)
          entry.key: (entry.value as List? ?? const [])
              .map((value) => value.toString())
              .toList(),
      },
      portraitPath: json['portraitPath'] as String? ?? '',
      referenceImages: (json['referenceImages'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      schemaVersion: json['schemaVersion'] as int? ?? 1,
    );
  }

  factory CharacterStudioRecord.fromStarter(
    StarterCharacterSheet sheet,
    String projectId,
    int index,
  ) =>
      CharacterStudioRecord(
        id: 'character-$projectId-$index',
        template: index == 0
            ? 'Protagonist'
            : index == 1
                ? 'Primary Opposition'
                : 'Key Ally',
        status: 'Active',
        fields: {
          'identity.fullName': sheet.name,
          'identity.role': sheet.role,
        },
        customFields: const {},
        connections: const {},
      );
}

class CharacterStudioStore {
  const CharacterStudioStore(this.projectId);

  final String projectId;
  String get key => 'author_studio.characters.v1.$projectId';

  Future<List<CharacterStudioRecord>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(key);
    if (encoded == null) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return [];
    return decoded
        .map((value) => CharacterStudioRecord.fromJson(
              Map<String, dynamic>.from(value as Map),
            ))
        .toList();
  }

  Future<void> save(List<CharacterStudioRecord> records) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      key,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }
}

class CharacterBoardView extends StatefulWidget {
  const CharacterBoardView({super.key, required this.project});

  final StarterProject project;

  @override
  State<CharacterBoardView> createState() => _CharacterBoardViewState();
}

class _CharacterBoardViewState extends State<CharacterBoardView> {
  final searchController = TextEditingController();
  List<CharacterStudioRecord> characters = [];
  CharacterStudioRecord? selected;
  String section = 'Overview';
  bool loading = true;

  CharacterStudioStore get store => CharacterStudioStore(widget.project.id);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var loaded = await store.load();
    if (loaded.isEmpty && widget.project.characterSheets.isNotEmpty) {
      loaded = widget.project.characterSheets
          .asMap()
          .entries
          .map((entry) => CharacterStudioRecord.fromStarter(
                entry.value,
                widget.project.id,
                entry.key,
              ))
          .toList();
      await store.save(loaded);
    }
    if (!mounted) return;
    setState(() {
      characters = loaded;
      selected = loaded.where((item) => !item.isArchived).firstOrNull ??
          loaded.firstOrNull;
      loading = false;
    });
  }

  Future<void> _persist() => store.save(characters);

  Future<void> _upsert([CharacterStudioRecord? existing]) async {
    final updated = await showDialog<CharacterStudioRecord>(
      context: context,
      builder: (context) => _CharacterEditorDialog(existing: existing),
    );
    if (updated == null) return;
    setState(() {
      final index = characters.indexWhere((item) => item.id == updated.id);
      if (index < 0) {
        characters.add(updated);
      } else {
        characters[index] = updated;
      }
      selected = updated;
      section = 'Overview';
    });
    await _persist();
  }

  Future<void> _toggleArchive(CharacterStudioRecord character) async {
    final updated = character.copyWith(
      status: character.isArchived ? 'Active' : 'Archived',
    );
    setState(() {
      characters[characters.indexWhere((item) => item.id == character.id)] =
          updated;
      selected = updated;
    });
    await _persist();
  }

  Future<void> _duplicate(CharacterStudioRecord character) async {
    final duplicate = character.copyWith(
      id: 'character-${DateTime.now().microsecondsSinceEpoch}',
      status: 'Active',
      fields: {
        ...character.fields,
        'identity.fullName': '${character.name} Copy',
      },
    );
    setState(() {
      characters.add(duplicate);
      selected = duplicate;
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final query = searchController.text.trim().toLowerCase();
    final visible = characters.where((character) {
      if (query.isEmpty) return true;
      return [
        character.name,
        character.template,
        character.role,
        ...character.fields.values,
        ...character.customFields.entries
            .expand((entry) => [entry.key, entry.value]),
      ].join(' ').toLowerCase().contains(query);
    }).toList();

    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Character Studio',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              )),
                      const SizedBox(height: 4),
                      Text(
                          'Develop the cast across story, world, and timeline.',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                FilledButton.icon(
                  key: const Key('add-character-button'),
                  onPressed: () => _upsert(),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add character'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('character-search-field'),
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Search characters',
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, constraints) {
              final roster = _CharacterRoster(
                characters: visible,
                selectedId: selected?.id,
                onSelected: (character) => setState(() {
                  selected = character;
                  section = 'Overview';
                }),
              );
              final detail = selected == null
                  ? const _CharacterEmptyState()
                  : _CharacterDetail(
                      character: selected!,
                      section: section,
                      onSectionChanged: (value) =>
                          setState(() => section = value),
                      onEdit: () => _upsert(selected),
                      onArchive: () => _toggleArchive(selected!),
                      onDuplicate: () => _duplicate(selected!),
                    );
              if (constraints.maxWidth < 820) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [roster, const SizedBox(height: 16), detail],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: roster),
                  const SizedBox(width: 18),
                  Expanded(child: detail),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CharacterRoster extends StatelessWidget {
  const _CharacterRoster({
    required this.characters,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CharacterStudioRecord> characters;
  final String? selectedId;
  final ValueChanged<CharacterStudioRecord> onSelected;

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) return const _CharacterEmptyState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cast',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...characters.map((character) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selectedId == character.id
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  selected: selectedId == character.id,
                  onTap: () => onSelected(character),
                  leading: _CharacterPortrait(character: character, size: 42),
                  title: Text(character.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(character.template),
                  trailing: character.isArchived
                      ? const Icon(Icons.archive_outlined, size: 18)
                      : null,
                ),
              ),
            )),
      ],
    );
  }
}

class _CharacterDetail extends StatelessWidget {
  const _CharacterDetail({
    required this.character,
    required this.section,
    required this.onSectionChanged,
    required this.onEdit,
    required this.onArchive,
    required this.onDuplicate,
  });

  final CharacterStudioRecord character;
  final String section;
  final ValueChanged<String> onSectionChanged;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CharacterPortrait(character: character, size: 88),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(character.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(character.role,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    Chip(label: Text(character.template)),
                    Chip(label: Text(character.status)),
                  ]),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Character actions',
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'duplicate') onDuplicate();
                if (value == 'archive') onArchive();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'edit', child: Text('Edit character')),
                const PopupMenuItem(
                    value: 'duplicate', child: Text('Duplicate')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(character.isArchived ? 'Restore' : 'Archive'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: _characterSections
                .map((item) => ButtonSegment(value: item, label: Text(item)))
                .toList(),
            selected: {section},
            showSelectedIcon: false,
            onSelectionChanged: (value) => onSectionChanged(value.first),
          ),
        ),
        const SizedBox(height: 16),
        _CharacterSection(character: character, section: section),
      ],
    );
  }
}

class _CharacterSection extends StatelessWidget {
  const _CharacterSection({required this.character, required this.section});

  final CharacterStudioRecord character;
  final String section;

  @override
  Widget build(BuildContext context) {
    if (section == 'Overview') {
      return _CharacterOverview(character: character);
    }
    final key = section.toLowerCase().replaceAll(' ', '');
    if (const [
      'relationships',
      'scenes',
      'timeline',
      'locations',
      'factions',
      'items',
      'plotthreads',
      'connections'
    ].contains(key)) {
      final links = character.connections[key] ?? const [];
      return _CharacterConnectionList(title: section, links: links);
    }
    final prefix = '${section.toLowerCase()}.';
    final values = character.fields.entries
        .where((entry) =>
            entry.key.startsWith(prefix) && entry.value.trim().isNotEmpty)
        .toList();
    if (section == 'Identity') {
      values.addAll(character.fields.entries
          .where((entry) => entry.key == 'identity.role'));
    }
    final custom = character.customFields.entries
        .where((entry) => entry.key.toLowerCase().startsWith(prefix))
        .toList();
    if (values.isEmpty && custom.isEmpty) {
      return _SectionEmpty(section: section);
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [...values, ...custom]
          .map((entry) => SizedBox(
                width: 260,
                child: _DataField(
                  label: _labelForPath(entry.key),
                  value: entry.value,
                ),
              ))
          .toList(),
    );
  }
}

class _CharacterOverview extends StatelessWidget {
  const _CharacterOverview({required this.character});
  final CharacterStudioRecord character;

  @override
  Widget build(BuildContext context) {
    final highlights = <MapEntry<String, String>>[
      MapEntry('Primary goal', character.fields['goals.primaryGoal'] ?? ''),
      MapEntry(
          'Motivation',
          character.fields['goals.motivation'] ??
              character.fields['psychology.primaryMotivation'] ??
              ''),
      MapEntry('Core desire', character.fields['psychology.coreDesire'] ?? ''),
      MapEntry('Arc', character.fields['arc.startingState'] ?? ''),
    ];
    final stats = <MapEntry<String, int>>[
      MapEntry(
          'Relationships', character.connections['relationships']?.length ?? 0),
      MapEntry('Scenes', character.connections['scenes']?.length ?? 0),
      MapEntry('Timeline', character.connections['timeline']?.length ?? 0),
      MapEntry('Locations', character.connections['locations']?.length ?? 0),
      MapEntry('Factions', character.connections['factions']?.length ?? 0),
      MapEntry(
          'Plot threads', character.connections['plotthreads']?.length ?? 0),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: highlights
              .map((entry) => SizedBox(
                    width: 260,
                    child: _DataField(
                      label: entry.key,
                      value: entry.value.isEmpty ? 'Not set' : entry.value,
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        Text('Connected record statistics',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: stats
              .map((entry) => Chip(label: Text('${entry.key}  ${entry.value}')))
              .toList(),
        ),
      ],
    );
  }
}

class _DataField extends StatelessWidget {
  const _DataField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(value),
          ],
        ),
      );
}

class _CharacterConnectionList extends StatelessWidget {
  const _CharacterConnectionList({required this.title, required this.links});
  final String title;
  final List<String> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return _SectionEmpty(section: title, connected: true);
    return Column(
      children: links
          .map((link) => ListTile(
                leading: const Icon(Icons.link_rounded),
                title: Text(link),
              ))
          .toList(),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.section, this.connected = false});
  final String section;
  final bool connected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(connected
            ? 'No live $section connections yet. Connections will appear here without duplicating their source records.'
            : 'No $section details yet. Edit this character to develop this section.'),
      );
}

class _CharacterPortrait extends StatelessWidget {
  const _CharacterPortrait({required this.character, required this.size});
  final CharacterStudioRecord character;
  final double size;

  @override
  Widget build(BuildContext context) {
    final file =
        character.portraitPath.isEmpty ? null : File(character.portraitPath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: file != null && file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : ColoredBox(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.person_rounded,
                    size: size * .5,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
      ),
    );
  }
}

class _CharacterEmptyState extends StatelessWidget {
  const _CharacterEmptyState();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
            'No characters yet. Add a character to begin developing the cast.'),
      );
}

class _CharacterEditorDialog extends StatefulWidget {
  const _CharacterEditorDialog({this.existing});
  final CharacterStudioRecord? existing;

  @override
  State<_CharacterEditorDialog> createState() => _CharacterEditorDialogState();
}

class _CharacterEditorDialogState extends State<_CharacterEditorDialog> {
  static const templates = [
    'Standard Character',
    'Protagonist',
    'Antagonist',
    'Supporting Character',
    'Romance Character',
    'Villain',
    'Custom',
  ];

  late final Map<String, TextEditingController> controllers;
  late String template;
  late String portraitPath;
  late Map<String, String> customFields;
  String editorSection = 'Identity';

  @override
  void initState() {
    super.initState();
    template = widget.existing?.template ?? templates.first;
    portraitPath = widget.existing?.portraitPath ?? '';
    customFields = {...?widget.existing?.customFields};
    controllers = {
      for (final field in _characterFieldDefinitions)
        field.path: TextEditingController(
            text: widget.existing?.fields[field.path] ?? ''),
      'identity.role': TextEditingController(
          text: widget.existing?.fields['identity.role'] ?? ''),
    };
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPortrait() async {
    const group =
        XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'webp']);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file != null && mounted) setState(() => portraitPath = file.path);
  }

  Future<void> _addCustomField() async {
    final name = TextEditingController();
    final value = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add custom field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Field name')),
            const SizedBox(height: 12),
            TextField(
                controller: value,
                decoration: const InputDecoration(labelText: 'Value')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, name.text.trim().isNotEmpty),
              child: const Text('Add')),
        ],
      ),
    );
    if (accepted == true) {
      setState(
          () => customFields['custom.${name.text.trim()}'] = value.text.trim());
    }
    name.dispose();
    value.dispose();
  }

  void _save() {
    if (controllers['identity.fullName']!.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      CharacterStudioRecord(
        id: widget.existing?.id ??
            'character-${DateTime.now().microsecondsSinceEpoch}',
        template: template,
        status: widget.existing?.status ?? 'Active',
        fields: {
          for (final entry in controllers.entries)
            if (entry.value.text.trim().isNotEmpty)
              entry.key: entry.value.text.trim(),
        },
        customFields: customFields,
        connections: widget.existing?.connections ?? const {},
        portraitPath: portraitPath,
        referenceImages: widget.existing?.referenceImages ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = _characterFieldDefinitions
        .where((field) => field.section == editorSection.toLowerCase())
        .toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: Text(
                        widget.existing == null
                            ? 'Add character'
                            : 'Edit character',
                        style: Theme.of(context).textTheme.headlineSmall)),
                IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                InkWell(
                  onTap: _pickPortrait,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 88,
                    child: Column(children: [
                      _CharacterPortrait(
                        character: CharacterStudioRecord(
                          id: '',
                          template: template,
                          status: 'Active',
                          fields: const {},
                          customFields: const {},
                          connections: const {},
                          portraitPath: portraitPath,
                        ),
                        size: 72,
                      ),
                      const SizedBox(height: 4),
                      const Text('Portrait', style: TextStyle(fontSize: 12)),
                    ]),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: template,
                    decoration: const InputDecoration(labelText: 'Template'),
                    items: templates
                        .map((item) =>
                            DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => template = value ?? template),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: const [
                    'Identity',
                    'Appearance',
                    'Personality',
                    'Psychology',
                    'History',
                    'Goals',
                    'Arc',
                    'Voice',
                    'Notes'
                  ]
                      .map((item) =>
                          ButtonSegment(value: item, label: Text(item)))
                      .toList(),
                  selected: {editorSection},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => editorSection = value.first),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (editorSection == 'Identity')
                        SizedBox(
                          width: 390,
                          child: TextField(
                              controller: controllers['identity.role'],
                              decoration: const InputDecoration(
                                  labelText: 'Story role')),
                        ),
                      ...fields.map((field) => SizedBox(
                            width: field.long ? 792 : 390,
                            child: TextField(
                              key: field.path == 'identity.fullName'
                                  ? const Key('character-name-field')
                                  : null,
                              controller: controllers[field.path],
                              minLines: field.long ? 3 : 1,
                              maxLines: field.long ? 5 : 1,
                              decoration: InputDecoration(
                                  labelText: field.label,
                                  suffixText:
                                      field.required ? 'Required' : null),
                            ),
                          )),
                      ...customFields.entries.map((entry) => SizedBox(
                            width: 390,
                            child: ListTile(
                              title: Text(_labelForPath(entry.key)),
                              subtitle: Text(entry.value.isEmpty
                                  ? 'No value'
                                  : entry.value),
                              trailing: IconButton(
                                tooltip: 'Remove custom field',
                                onPressed: () => setState(
                                    () => customFields.remove(entry.key)),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                TextButton.icon(
                    onPressed: _addCustomField,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add field')),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                    key: const Key('save-character-button'),
                    onPressed: _save,
                    child: const Text('Save character')),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

String _labelForPath(String path) {
  for (final field in _characterFieldDefinitions) {
    if (field.path == path) return field.label;
  }
  final raw = path.split('.').last;
  return raw
      .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
      .trim()
      .split(' ')
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
