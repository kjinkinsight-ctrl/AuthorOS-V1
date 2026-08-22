import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'character_service.dart';
import 'core/built_in_record_types.dart';
import 'core/character_record_types.dart';
import 'core/connected_domain.dart';
import 'core/record_inspection.dart';
import 'core/record_service.dart';
import 'core/record_types.dart';
import 'core/record_validation.dart';
import 'core/search_models.dart';
import 'knowledge_graph/open_in_graph.dart';
import 'local_image.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';

RecordTypeDefinition _characterTemplate(String label) {
  final templateId = _characterTemplateId(label);
  return BuiltInRecordTypes.registry().resolve(templateId);
}

List<RecordTemplateSection> _characterTemplateSections(String label) {
  final template = _characterTemplate(label);
  final visible = template.extensionData['visibleSections'];
  final visibleIds = visible is List
      ? visible.map((value) => value.toString()).toSet()
      : const <String>{};
  final sections = template.sections
      .where((section) => visibleIds.isEmpty || visibleIds.contains(section.id))
      .toList()
    ..sort((left, right) => left.order.compareTo(right.order));
  return sections;
}

enum CharacterWorkspaceDestination { manuscript, timeline, codex, world, plot }

enum CharacterSaveState { saved, saving, unsaved, error }

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
    this.templateId,
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
  final String? templateId;

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
    String? templateId,
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
        templateId: templateId ?? this.templateId,
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
        if (templateId != null) 'templateId': templateId!,
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
      templateId: json['templateId'] as String?,
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
  CharacterStudioStore(
    this.projectId, {
    DriftConnectedDomainRepository? repository,
  })  : repository = repository ?? authorOsRepository,
        recordService = RecordService(
          projectId: projectId,
          repository: repository ?? authorOsRepository,
        ),
        characterService = CharacterService(
          projectId: projectId,
          repository: repository ?? authorOsRepository,
        );

  final String projectId;
  final DriftConnectedDomainRepository repository;
  final RecordService recordService;
  final CharacterService characterService;

  Future<List<CharacterStudioRecord>> load() async {
    final records = await repository.recordsByTypeAndScope(
      typeId: 'character',
      scopeId: projectId,
    );
    final characters = <CharacterStudioRecord>[];
    for (final record in records) {
      final backlinks = await repository.backlinks(record.id);
      final connections = <String, List<String>>{};
      for (final link in backlinks) {
        final category = link.label.startsWith('legacy:')
            ? link.label.substring('legacy:'.length)
            : link.typeId;
        connections
            .putIfAbsent(category, () => [])
            .add(link.sourceId == record.id ? link.targetId : link.sourceId);
      }
      characters.add(_fromAuthorRecord(record, connections));
    }
    return characters;
  }

  Future<void> save(List<CharacterStudioRecord> records) async {
    final existing = {
      for (final record in await repository.recordsByTypeAndScope(
        typeId: 'character',
        scopeId: projectId,
      ))
        record.id: record,
    };
    for (final character in records) {
      final current = existing[character.id];
      final record = _toAuthorRecord(character, current);
      if (current == null) {
        await recordService.createRecord(record);
      } else {
        await recordService.updateRecord(record);
      }
    }
    for (final character in records) {
      for (final connection in character.connections.entries) {
        for (final targetId in connection.value) {
          await characterService.connectCharacter(
            characterId: character.id,
            targetId: targetId,
            typeId: 'relatedTo',
            label: 'legacy:${connection.key}',
            direction: RecordLinkDirection.undirected,
          );
        }
      }
    }
  }

  AuthorRecord _toAuthorRecord(
    CharacterStudioRecord character,
    AuthorRecord? existing,
  ) {
    final timestamp = DateTime.now().toUtc();
    return AuthorRecord(
      id: character.id,
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: character.name,
      status: character.isArchived
          ? AuthorRecordStatus.archived
          : AuthorRecordStatus.active,
      schemaVersion: CharacterRecordTypes.character.templateVersion,
      templateId:
          character.templateId ?? _characterTemplateId(character.template),
      templateVersion: 1,
      revision: (existing?.revision ?? 0) + 1,
      fields: {
        for (final entry in character.fields.entries)
          entry.key: _characterFieldValue(entry.key, entry.value),
        '_character.template': character.template,
        '_character.customFields': character.customFields,
        '_character.portraitPath': character.portraitPath,
        '_character.referenceImages': character.referenceImages,
      },
      createdAt: existing?.createdAt ?? timestamp,
      updatedAt: timestamp,
      extensionData: const {'characterStudio': true},
    );
  }

  CharacterStudioRecord _fromAuthorRecord(
    AuthorRecord record,
    Map<String, List<String>> connections,
  ) {
    final custom = record.fields['_character.customFields'];
    final references = record.fields['_character.referenceImages'];
    return CharacterStudioRecord(
      id: record.id,
      template: record.fields['_character.template'] as String? ??
          'Standard Character',
      templateId: record.templateId,
      status:
          record.status == AuthorRecordStatus.archived ? 'Archived' : 'Active',
      fields: {
        for (final entry in record.fields.entries)
          if (!entry.key.startsWith('_character.'))
            entry.key: _characterDisplayValue(entry.value),
      },
      customFields: custom is Map
          ? custom.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      connections: connections,
      portraitPath: record.fields['_character.portraitPath'] as String? ?? '',
      referenceImages: references is List
          ? references.map((value) => value.toString()).toList()
          : const [],
      schemaVersion: record.schemaVersion,
    );
  }
}

const _characterListFields = <String>{
  'identity.aliases',
  'identity.nicknames',
  'identity.titles',
  'identity.affiliations',
  'personality.coreTraits',
  'personality.positiveTraits',
  'personality.negativeTraits',
  'personality.strengths',
  'personality.weaknesses',
  'personality.fears',
  'personality.insecurities',
  'personality.habits',
  'personality.quirks',
  'personality.values',
  'psychology.secondaryMotivations',
  'psychology.secrets',
  'voice.expressions',
  'voice.verbalHabits',
};

Object _characterFieldValue(String path, String value) {
  final definition = CharacterRecordTypes.character.fields
      .where((field) => field.id == path)
      .firstOrNull;
  if (definition?.type == RecordFieldType.boolean) {
    return value.toLowerCase() == 'true';
  }
  if (definition?.type == RecordFieldType.number ||
      definition?.type == RecordFieldType.rating) {
    return num.tryParse(value) ?? value;
  }
  if (_characterListFields.contains(path) ||
      const {
        RecordFieldType.multipleChoice,
        RecordFieldType.tags,
        RecordFieldType.list,
        RecordFieldType.checklist,
      }.contains(definition?.type)) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (definition?.type == RecordFieldType.table) {
    try {
      final decoded = jsonDecode(value);
      return decoded is List ? decoded : value;
    } on FormatException {
      return value;
    }
  }
  return value;
}

String _characterDisplayValue(Object? value) {
  if (value is Iterable) return value.join(', ');
  if (value is Map) return jsonEncode(value);
  return value?.toString() ?? '';
}

String _characterTemplateId(String label) => switch (label) {
      'Standard Character' || 'Basic Character' => 'character-basic',
      'Protagonist' || 'Main Character' => 'character-main',
      'Primary Opposition' || 'Antagonist' => 'character-antagonist',
      'Supporting Character' || 'Key Ally' => 'character-supporting',
      'Romance Character' => 'character-love-interest',
      'Villain' => 'character-villain',
      'Hero' => 'character-hero',
      'POV Character' => 'character-pov',
      'Fae Character' => 'character-fae',
      'Fantasy Character' => 'character-fantasy',
      'Modern Character' => 'character-modern',
      'Historical Character' => 'character-historical',
      _ => 'character-basic',
    };

class CharacterBoardView extends StatefulWidget {
  const CharacterBoardView({
    super.key,
    required this.project,
    this.repository,
    this.onNavigate,
    this.onOpenInGraph,
    this.branchId,
    this.branchName,
  });

  final StarterProject project;
  final DriftConnectedDomainRepository? repository;
  final ValueChanged<CharacterWorkspaceDestination>? onNavigate;

  /// Asks the shell for the Knowledge Graph, focused on a record.
  ///
  /// Separate from [onNavigate], which names a Studio and carries no record.
  /// Merging them would conflate "go to that Studio" with "go to this record".
  final ValueChanged<SearchNavigationTarget>? onOpenInGraph;
  final String? branchId;
  final String? branchName;

  @override
  State<CharacterBoardView> createState() => _CharacterBoardViewState();
}

class _CharacterBoardViewState extends State<CharacterBoardView> {
  final searchController = TextEditingController();
  List<CharacterStudioRecord> characters = [];
  CharacterStudioRecord? selected;
  String section = 'Overview';
  bool loading = true;
  CharacterSaveState saveState = CharacterSaveState.saved;
  Timer? _saveTimer;

  CharacterStudioStore get store => CharacterStudioStore(
        widget.project.id,
        repository: widget.repository,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
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

  Future<void> _flushSave() async {
    _saveTimer?.cancel();
    if (saveState == CharacterSaveState.saved) return;
    setState(() => saveState = CharacterSaveState.saving);
    try {
      if (widget.branchId != null && selected != null) {
        await store.characterService.overrideCharacterInBranch(
          widget.branchId!,
          selected!.id,
          title: selected!.name,
          fields: {
            for (final entry in selected!.fields.entries)
              entry.key: _characterFieldValue(entry.key, entry.value),
          },
        );
      } else {
        await _persist();
      }
      if (mounted) setState(() => saveState = CharacterSaveState.saved);
    } catch (_) {
      if (mounted) setState(() => saveState = CharacterSaveState.error);
    }
  }

  void _scheduleSave(CharacterStudioRecord updated) {
    setState(() {
      characters[characters.indexWhere((item) => item.id == updated.id)] =
          updated;
      selected = updated;
      saveState = CharacterSaveState.unsaved;
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 900), _flushSave);
  }

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

  Future<void> _changeTemplate(CharacterStudioRecord character) async {
    var value = character.template;
    final selectedTemplate = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change character template'),
          content: DropdownButtonFormField<String>(
            initialValue: _CharacterEditorDialogState.templates.contains(value)
                ? value
                : _CharacterEditorDialogState.templates.first,
            items: _CharacterEditorDialogState.templates
                .map((template) => DropdownMenuItem(
                      value: template,
                      child: Text(template),
                    ))
                .toList(),
            onChanged: (next) => setDialogState(() => value = next ?? value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, value),
              child: const Text('Apply template'),
            ),
          ],
        ),
      ),
    );
    if (selectedTemplate == null || selectedTemplate == character.template) {
      return;
    }
    final updated = character.copyWith(template: selectedTemplate);
    setState(() {
      characters[characters.indexWhere((item) => item.id == character.id)] =
          updated;
      selected = updated;
      section = 'Overview';
    });
    await _persist();
  }

  Future<void> _showInspector(CharacterStudioRecord character) async {
    final inspection =
        await store.characterService.inspectCharacter(character.id);
    if (!mounted || inspection == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Inspector: ${inspection.title}'),
        content: SizedBox(
          width: 620,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: Text(inspection.validation.state.name.toUpperCase()),
                subtitle: Text(inspection.validation.issues.isEmpty
                    ? 'No validation issues.'
                    : inspection.validation.issues
                        .map((issue) => issue.message)
                        .join('\n')),
              ),
              ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: const Text('Connections'),
                subtitle: Text(
                  '${inspection.incomingConnections.length} incoming, '
                  '${inspection.outgoingConnections.length} outgoing',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('History'),
                subtitle: Text(
                  '${inspection.history.versionCount} versions, '
                  '${inspection.history.auditEventCount} audit events',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: const Text('Scope and branch'),
                subtitle: Text(
                  '${inspection.scope.canonStatus.name} / '
                  '${inspection.scope.branchState.name}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showHistory(CharacterStudioRecord character) async {
    final versions =
        await store.characterService.getCharacterHistory(character.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('History: ${character.name}'),
        content: SizedBox(
          width: 620,
          child: versions.isEmpty
              ? const Text('No historical versions yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: versions.length,
                  itemBuilder: (context, index) {
                    final version = versions.reversed.elementAt(index);
                    return ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: Text(version.summary),
                      subtitle: Text(
                        '${version.changeType.name} · ${version.createdAt.toLocal()}',
                      ),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Historical snapshot'),
                          content: SingleChildScrollView(
                            child: SelectableText(
                              const JsonEncoder.withIndent('  ')
                                  .convert(version.snapshot),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _flushSave,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _flushSave,
      },
      child: Focus(
        autofocus: true,
        child: Material(
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
                      : FutureBuilder<RecordTypeRegistry>(
                          future: store.recordService.registry(),
                          builder: (context, registry) {
                            RecordTypeDefinition? definition;
                            try {
                              definition = registry.data?.resolve(
                                selected!.templateId ??
                                    _characterTemplateId(selected!.template),
                              );
                            } on StateError {
                              definition = null;
                            }
                            return _CharacterDetail(
                              character: selected!,
                              service: store.characterService,
                              templateDefinition: definition,
                              section: section,
                              onSectionChanged: (value) =>
                                  setState(() => section = value),
                              onEdit: () => _upsert(selected),
                              onArchive: () => _toggleArchive(selected!),
                              onDuplicate: () => _duplicate(selected!),
                              onChangeTemplate: () =>
                                  _changeTemplate(selected!),
                              onInspector: () => _showInspector(selected!),
                              onHistory: () => _showHistory(selected!),
                              saveState: saveState,
                              onChanged: _scheduleSave,
                              onNavigate: widget.onNavigate,
                              onOpenInGraph: widget.onOpenInGraph,
                              branchId: widget.branchId,
                              branchName: widget.branchName,
                            );
                          },
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
    required this.service,
    this.templateDefinition,
    required this.section,
    required this.onSectionChanged,
    required this.onEdit,
    required this.onArchive,
    required this.onDuplicate,
    required this.onChangeTemplate,
    required this.onInspector,
    required this.onHistory,
    required this.saveState,
    required this.onChanged,
    this.onNavigate,
    this.onOpenInGraph,
    this.branchId,
    this.branchName,
  });

  final CharacterStudioRecord character;
  final CharacterService service;
  final RecordTypeDefinition? templateDefinition;
  final String section;
  final ValueChanged<String> onSectionChanged;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDuplicate;
  final VoidCallback onChangeTemplate;
  final VoidCallback onInspector;
  final VoidCallback onHistory;
  final CharacterSaveState saveState;
  final ValueChanged<CharacterStudioRecord> onChanged;
  final ValueChanged<CharacterWorkspaceDestination>? onNavigate;

  /// Asks the shell for the Knowledge Graph, focused on a record.
  ///
  /// Separate from [onNavigate], which names a Studio and carries no record.
  /// Merging them would conflate "go to that Studio" with "go to this record".
  final ValueChanged<SearchNavigationTarget>? onOpenInGraph;
  final String? branchId;
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final template =
        templateDefinition ?? _characterTemplate(character.template);
    final visible = template.extensionData['visibleSections'];
    final visibleIds = visible is List
        ? visible.map((value) => value.toString()).toSet()
        : const <String>{};
    final sections = template.sections
        .where((item) => visibleIds.isEmpty || visibleIds.contains(item.id))
        .toList()
      ..sort((left, right) => left.order.compareTo(right.order));
    final selectedSection =
        sections.where((item) => item.title == section).firstOrNull;
    final effectiveSection =
        section == 'Overview' || selectedSection != null ? section : 'Overview';
    final requiredFields = template.fields.where((field) => field.required);
    final completedRequired = requiredFields.where((field) {
      final value = character.fields[field.id];
      return value != null && value.trim().isNotEmpty;
    }).length;
    final completion = requiredFields.isEmpty
        ? 1.0
        : completedRequired / requiredFields.length;
    final optionalFields = template.fields.where((field) => !field.required);
    final completedOptional = optionalFields.where((field) {
      final value = character.fields[field.id];
      return value != null && value.trim().isNotEmpty;
    }).length;
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
                    Chip(
                      key: const Key('character-completion-indicator'),
                      avatar: Icon(
                        completion == 1
                            ? Icons.check_circle_outline_rounded
                            : Icons.pending_outlined,
                        size: 18,
                      ),
                      label: Text('${(completion * 100).round()}% complete'),
                    ),
                    Chip(
                      key: const Key('character-save-state'),
                      avatar: Icon(_saveStateIcon(saveState), size: 18),
                      label: Text(_saveStateLabel(saveState)),
                    ),
                  ]),
                  if (optionalFields.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$completedOptional optional details completed',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  _CharacterRecordMetadata(
                    characterId: character.id,
                    service: service,
                    branchId: branchId,
                  ),
                  if (branchId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Editing ${branchName ?? branchId}: changes create a branch override and do not modify Canon.',
                        key: const Key('character-branch-edit-notice'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Character actions',
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'duplicate') onDuplicate();
                if (value == 'archive') onArchive();
                if (value == 'template') onChangeTemplate();
                if (value == 'inspector') onInspector();
                if (value == 'history') onHistory();
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
                const PopupMenuItem(
                  value: 'template',
                  child: Text('Change template'),
                ),
                const PopupMenuItem(
                  key: Key('character-action-inspector'),
                  value: 'inspector',
                  child: Text('View Inspector'),
                ),
                const PopupMenuItem(
                  key: Key('character-action-history'),
                  value: 'history',
                  child: Text('View History'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final destinations = <RecordTemplateSection>[
              const RecordTemplateSection(
                id: 'overview',
                title: 'Overview',
                order: 0,
              ),
              ...sections.where((item) => item.id != 'overview'),
            ];
            final content = _CharacterSection(
              character: character,
              section: effectiveSection,
              definition: selectedSection,
              template: template,
              service: service,
              onChanged: onChanged,
              onSectionChanged: onSectionChanged,
              onNavigate: onNavigate,
              onOpenInGraph: onOpenInGraph,
            );
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: const Key('character-section-navigation'),
                    initialValue: effectiveSection,
                    decoration: const InputDecoration(labelText: 'Section'),
                    items: destinations
                        .map((item) => DropdownMenuItem(
                              value: item.title,
                              child: Text(item.title),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onSectionChanged(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  content,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 220,
                  height: 620,
                  child: ListView(
                    key: const Key('character-section-navigation'),
                    children: destinations
                        .map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                key: Key('character-section-${item.id}'),
                                selected: item.title == effectiveSection,
                                dense: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                leading: item.title != 'Overview' &&
                                        !_sectionHasData(character, item)
                                    ? const Icon(Icons.circle_outlined,
                                        size: 14)
                                    : const Icon(Icons.circle, size: 10),
                                title: Text(item.title),
                                onTap: () => onSectionChanged(item.title),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: content),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _saveStateLabel(CharacterSaveState state) => switch (state) {
      CharacterSaveState.saved => 'Saved',
      CharacterSaveState.saving => 'Saving',
      CharacterSaveState.unsaved => 'Unsaved changes',
      CharacterSaveState.error => 'Save error',
    };

IconData _saveStateIcon(CharacterSaveState state) => switch (state) {
      CharacterSaveState.saved => Icons.cloud_done_outlined,
      CharacterSaveState.saving => Icons.sync_rounded,
      CharacterSaveState.unsaved => Icons.edit_outlined,
      CharacterSaveState.error => Icons.error_outline_rounded,
    };

class _CharacterRecordMetadata extends StatelessWidget {
  const _CharacterRecordMetadata({
    required this.characterId,
    required this.service,
    this.branchId,
  });

  final String characterId;
  final CharacterService service;
  final String? branchId;

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: service.inspectCharacter(characterId, branchId: branchId),
        builder: (context, snapshot) {
          final inspection = snapshot.data;
          if (inspection == null) {
            return const SizedBox(height: 8);
          }
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${inspection.canonStatus.name.toUpperCase()} · '
              '${inspection.scope.branchState.name} · '
              'Modified ${inspection.updatedAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        },
      );
}

bool _sectionHasData(
  CharacterStudioRecord character,
  RecordTemplateSection section,
) {
  if (section.extensionData['connectionBacked'] == true) {
    return character.connections[section.id]?.isNotEmpty == true;
  }
  return section.fieldIds.any(
    (fieldId) => character.fields[fieldId]?.trim().isNotEmpty == true,
  );
}

class _CharacterSection extends StatelessWidget {
  const _CharacterSection({
    required this.character,
    required this.section,
    required this.definition,
    required this.template,
    required this.service,
    required this.onChanged,
    required this.onSectionChanged,
    this.onNavigate,
    this.onOpenInGraph,
  });

  final CharacterStudioRecord character;
  final String section;
  final RecordTemplateSection? definition;
  final RecordTypeDefinition template;
  final CharacterService service;
  final ValueChanged<CharacterStudioRecord> onChanged;
  final ValueChanged<String> onSectionChanged;
  final ValueChanged<CharacterWorkspaceDestination>? onNavigate;

  /// Asks the shell for the Knowledge Graph, focused on a record.
  ///
  /// Separate from [onNavigate], which names a Studio and carries no record.
  /// Merging them would conflate "go to that Studio" with "go to this record".
  final ValueChanged<SearchNavigationTarget>? onOpenInGraph;

  @override
  Widget build(BuildContext context) {
    if (section == 'Overview') {
      return _CharacterOverview(
        character: character,
        onSectionChanged: onSectionChanged,
      );
    }
    final sectionDefinition = definition;
    if (sectionDefinition == null) return _SectionEmpty(section: section);
    if (sectionDefinition.extensionData['connectionBacked'] == true) {
      if (sectionDefinition.id == 'relationships' ||
          sectionDefinition.id == 'family') {
        return _RelationshipWorkspace(
          character: character,
          service: service,
          familyOnly: sectionDefinition.id == 'family',
        );
      }
      return _CharacterConnectionsPanel(
        character: character,
        service: service,
        section: sectionDefinition,
        onNavigate: onNavigate,
        onOpenInGraph: onOpenInGraph,
      );
    }
    return _DynamicCharacterSectionEditor(
      key: ValueKey('${character.id}:${sectionDefinition.id}'),
      character: character,
      template: template,
      section: sectionDefinition,
      service: service,
      onChanged: onChanged,
    );
  }
}

class _DynamicCharacterSectionEditor extends StatefulWidget {
  const _DynamicCharacterSectionEditor({
    super.key,
    required this.character,
    required this.template,
    required this.section,
    required this.service,
    required this.onChanged,
  });

  final CharacterStudioRecord character;
  final RecordTypeDefinition template;
  final RecordTemplateSection section;
  final CharacterService service;
  final ValueChanged<CharacterStudioRecord> onChanged;

  @override
  State<_DynamicCharacterSectionEditor> createState() =>
      _DynamicCharacterSectionEditorState();
}

class _DynamicCharacterSectionEditorState
    extends State<_DynamicCharacterSectionEditor> {
  late final Map<String, TextEditingController> controllers;
  late Future<RecordValidationResult?> validation;

  @override
  void initState() {
    super.initState();
    final definitions = {
      for (final field in widget.template.fields) field.id: field,
    };
    controllers = {
      for (final fieldId in widget.section.fieldIds)
        if (definitions[fieldId] != null)
          fieldId: TextEditingController(
            text: widget.character.fields[fieldId] ??
                _characterDisplayValue(definitions[fieldId]!.defaultValue),
          ),
    };
    validation = _loadValidation();
  }

  Future<RecordValidationResult?> _loadValidation() async {
    final record = await widget.service.getCharacter(widget.character.id);
    return record == null ? null : widget.service.validateCharacter(record);
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() {
    final fields = {...widget.character.fields};
    for (final entry in controllers.entries) {
      if (entry.value.text.trim().isEmpty) {
        fields.remove(entry.key);
      } else {
        fields[entry.key] = entry.value.text.trim();
      }
    }
    widget.onChanged(widget.character.copyWith(fields: fields));
  }

  @override
  Widget build(BuildContext context) {
    final definitions = {
      for (final field in widget.template.fields) field.id: field,
    };
    final fields = widget.section.fieldIds
        .map((id) => definitions[id])
        .whereType<RecordFieldDefinition>()
        .where((field) => !field.hidden)
        .toList();
    return FutureBuilder<RecordValidationResult?>(
      future: validation,
      builder: (context, snapshot) {
        final issues = snapshot.data?.issues ?? const <RecordValidationIssue>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.section.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _ValidationBadge(issues: issues),
              ],
            ),
            const SizedBox(height: 12),
            if (fields.isEmpty)
              _SectionEmpty(section: widget.section.title)
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: fields
                    .map((field) => SizedBox(
                          width: _isLongCharacterField(field) ? 792 : 390,
                          child: _CharacterFieldEditor(
                            definition: field,
                            controller: controllers[field.id]!,
                            issues: issues
                                .where((issue) => issue.fieldId == field.id)
                                .toList(),
                            onChanged: _changed,
                          ),
                        ))
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}

class _ValidationBadge extends StatelessWidget {
  const _ValidationBadge({required this.issues});
  final List<RecordValidationIssue> issues;

  @override
  Widget build(BuildContext context) {
    final hasError = issues.any(
      (issue) => issue.severity == RecordValidationSeverity.error,
    );
    final state = hasError
        ? 'ERROR'
        : issues.isNotEmpty
            ? 'WARNING'
            : 'VALID';
    final icon = hasError
        ? Icons.error_outline_rounded
        : issues.isNotEmpty
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline_rounded;
    return Chip(
      key: const Key('character-validation-indicator'),
      avatar: Icon(icon, size: 18),
      label: Text(state),
    );
  }
}

class _RelationshipWorkspace extends StatefulWidget {
  const _RelationshipWorkspace({
    required this.character,
    required this.service,
    required this.familyOnly,
  });

  final CharacterStudioRecord character;
  final CharacterService service;
  final bool familyOnly;

  @override
  State<_RelationshipWorkspace> createState() => _RelationshipWorkspaceState();
}

class _RelationshipWorkspaceState extends State<_RelationshipWorkspace> {
  late Future<List<RecordLink>> relationships;

  @override
  void initState() {
    super.initState();
    relationships =
        widget.service.getCharacterRelationships(widget.character.id);
  }

  void _reload() => setState(() {
        relationships =
            widget.service.getCharacterRelationships(widget.character.id);
      });

  Future<void> _edit([RecordLink? existing]) async {
    final result = await showDialog<_RelationshipDraft>(
      context: context,
      builder: (context) => _RelationshipEditorDialog(
        characterId: widget.character.id,
        service: widget.service,
        existing: existing,
        familyOnly: widget.familyOnly,
      ),
    );
    if (result == null) return;
    if (existing == null) {
      await widget.service.connectCharacter(
        characterId: widget.character.id,
        targetId: result.targetId,
        typeId: result.typeId,
        direction: result.direction,
        metadata: result.metadata,
      );
    } else {
      await widget.service.updateCharacterConnection(
        widget.character.id,
        existing.id,
        typeId: result.typeId,
        metadata: result.metadata,
      );
    }
    _reload();
  }

  Future<void> _remove(RecordLink link) async {
    await widget.service
        .removeCharacterConnection(widget.character.id, link.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RecordLink>>(
        future: relationships,
        builder: (context, snapshot) {
          final familyTypes = {'parentOf', 'guardianOf'};
          final links = (snapshot.data ?? const <RecordLink>[])
              .where((link) =>
                  widget.familyOnly == familyTypes.contains(link.typeId))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.familyOnly ? 'Family' : 'Relationships',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  FilledButton.icon(
                    key: Key(widget.familyOnly
                        ? 'add-family-button'
                        : 'add-relationship-button'),
                    onPressed: _edit,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(widget.familyOnly
                        ? 'Add family connection'
                        : 'Add relationship'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (links.isEmpty)
                _SectionEmpty(
                  section: widget.familyOnly
                      ? 'family connections. Add the people who shaped this character'
                      : 'relationships. Add the people who shape this character\'s story',
                )
              else
                ...links.map((link) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        key: Key('relationship-link-${link.id}'),
                        leading: const Icon(Icons.people_outline_rounded),
                        title: FutureBuilder<AuthorRecord?>(
                          future: widget.service.repository.recordById(
                            link.sourceId == widget.character.id
                                ? link.targetId
                                : link.sourceId,
                          ),
                          builder: (context, record) => Text(
                            record.data?.title ?? link.typeId,
                          ),
                        ),
                        subtitle: Text([
                          link.typeId,
                          if (link.metadata['status'] != null)
                            link.metadata['status'],
                          if (link.metadata['strength'] != null)
                            'Strength ${link.metadata['strength']}',
                        ].join(' · ')),
                        onTap: () => _edit(link),
                        trailing: IconButton(
                          tooltip: 'Remove relationship',
                          onPressed: () => _remove(link),
                          icon: const Icon(Icons.link_off_rounded),
                        ),
                      ),
                    )),
            ],
          );
        },
      );
}

class _RelationshipDraft {
  const _RelationshipDraft({
    required this.targetId,
    required this.typeId,
    required this.direction,
    required this.metadata,
  });
  final String targetId;
  final String typeId;
  final RecordLinkDirection direction;
  final Map<String, Object?> metadata;
}

class _RelationshipEditorDialog extends StatefulWidget {
  const _RelationshipEditorDialog({
    required this.characterId,
    required this.service,
    required this.familyOnly,
    this.existing,
  });
  final String characterId;
  final CharacterService service;
  final bool familyOnly;
  final RecordLink? existing;

  @override
  State<_RelationshipEditorDialog> createState() =>
      _RelationshipEditorDialogState();
}

class _RelationshipEditorDialogState extends State<_RelationshipEditorDialog> {
  final search = TextEditingController();
  final status = TextEditingController();
  final strength = TextEditingController();
  final notes = TextEditingController();
  List<AuthorRecord> results = [];
  String? targetId;
  late String typeId;

  static const relationshipTypes = [
    'friendOf',
    'enemyOf',
    'alliedWith',
    'rivalOf',
    'partnerOf',
    'mentors',
    'protects',
    'employs',
    'trusts',
    'distrusts'
  ];
  static const familyTypes = ['parentOf', 'guardianOf'];

  @override
  void initState() {
    super.initState();
    typeId = widget.existing?.typeId ??
        (widget.familyOnly ? familyTypes.first : relationshipTypes.first);
    targetId = widget.existing == null
        ? null
        : widget.existing!.sourceId == widget.characterId
            ? widget.existing!.targetId
            : widget.existing!.sourceId;
    status.text = widget.existing?.metadata['status']?.toString() ?? '';
    strength.text = widget.existing?.metadata['strength']?.toString() ?? '';
    notes.text = widget.existing?.metadata['notes']?.toString() ?? '';
  }

  @override
  void dispose() {
    search.dispose();
    status.dispose();
    strength.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final hits = await widget.service.searchCharacters(query);
    final records = <AuthorRecord>[];
    for (final hit in hits.where((hit) => hit.recordId != widget.characterId)) {
      final record = await widget.service.getCharacter(hit.recordId);
      if (record != null) records.add(record);
    }
    if (mounted) setState(() => results = records);
  }

  void _save() {
    if (targetId == null) return;
    final undirected = {
      'friendOf',
      'enemyOf',
      'alliedWith',
      'rivalOf',
      'partnerOf'
    }.contains(typeId);
    Navigator.pop(
      context,
      _RelationshipDraft(
        targetId: targetId!,
        typeId: typeId,
        direction: undirected
            ? RecordLinkDirection.undirected
            : RecordLinkDirection.directed,
        metadata: {
          if (status.text.trim().isNotEmpty) 'status': status.text.trim(),
          if (num.tryParse(strength.text) != null)
            'strength': num.parse(strength.text),
          if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.existing == null ? 'Add relationship' : 'Edit relationship'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.existing == null) ...[
                  TextField(
                    key: const Key('relationship-target-search'),
                    controller: search,
                    decoration: const InputDecoration(
                      labelText: 'Find character',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onSubmitted: _search,
                  ),
                  ...results.map((record) => RadioListTile<String>(
                        value: record.id,
                        groupValue: targetId,
                        title: Text(record.title),
                        onChanged: (value) => setState(() => targetId = value),
                      )),
                ],
                DropdownButtonFormField<String>(
                  key: const Key('relationship-type-field'),
                  initialValue: typeId,
                  decoration:
                      const InputDecoration(labelText: 'Relationship type'),
                  items: (widget.familyOnly ? familyTypes : relationshipTypes)
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => typeId = value ?? typeId),
                ),
                TextField(
                    controller: status,
                    decoration: const InputDecoration(labelText: 'Status')),
                TextField(
                    controller: strength,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Strength')),
                TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              key: const Key('save-relationship-button'),
              onPressed: _save,
              child: const Text('Save relationship')),
        ],
      );
}

class _CharacterConnectionsPanel extends StatelessWidget {
  const _CharacterConnectionsPanel({
    required this.character,
    required this.service,
    required this.section,
    this.onNavigate,
    this.onOpenInGraph,
  });
  final CharacterStudioRecord character;
  final CharacterService service;
  final RecordTemplateSection section;
  final ValueChanged<CharacterWorkspaceDestination>? onNavigate;

  /// Asks the shell for the Knowledge Graph, focused on a record.
  ///
  /// Separate from [onNavigate], which names a Studio and carries no record.
  /// Merging them would conflate "go to that Studio" with "go to this record".
  final ValueChanged<SearchNavigationTarget>? onOpenInGraph;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<UniversalRecordInspection?>(
        future: service.inspectCharacter(character.id),
        builder: (context, snapshot) {
          final references =
              (snapshot.data?.references ?? const <ReferenceInspection>[])
                  .where((reference) =>
                      _referenceMatchesSection(reference, section.id))
                  .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(section.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  OpenInGraphButton(
                    recordId: character.id,
                    onOpen: onOpenInGraph == null
                        ? null
                        : () => onOpenInGraph!(
                              SearchNavigationTarget(
                                destination:
                                    SearchDestination.knowledgeGraph,
                                recordId: character.id,
                                projectId: service.projectId,
                              ),
                            ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (references.isEmpty)
                _SectionEmpty(section: _connectionEmptyMessage(section.id))
              else
                ...references.map((reference) => ListTile(
                      leading: Icon(reference.incoming
                          ? Icons.call_received_rounded
                          : Icons.call_made_rounded),
                      title: Text(reference.entity.title),
                      subtitle: Text(
                          '${reference.connectionType} · ${reference.incoming ? 'Incoming' : 'Outgoing'}'),
                      onTap: () {
                        final destination = _destinationForReference(reference);
                        if (destination != null) onNavigate?.call(destination);
                      },
                    )),
            ],
          );
        },
      );
}

bool _referenceMatchesSection(ReferenceInspection reference, String section) =>
    switch (section) {
      'timeline' => reference.kind == ReferenceKind.timeline,
      'manuscript' => const {
          ReferenceKind.manuscript,
          ReferenceKind.chapter,
          ReferenceKind.scene
        }.contains(reference.kind),
      'codex' => reference.kind == ReferenceKind.codex,
      'world' ||
      'factions' ||
      'locations' ||
      'items' =>
        reference.kind == ReferenceKind.world ||
            reference.kind == ReferenceKind.universalRecord,
      _ => true,
    };

String _connectionEmptyMessage(String section) => switch (section) {
      'timeline' =>
        'timeline events yet. Connect this character to an event to build their history',
      'manuscript' =>
        'manuscript appearances yet. Connect a scene or chapter to track their presence',
      'codex' =>
        'Story Codex references yet. Connect lore to build their knowledge context',
      'world' =>
        'World records yet. Connect places, cultures, magic, or technology',
      _ => '$section connections yet',
    };

CharacterWorkspaceDestination? _destinationForReference(
        ReferenceInspection reference) =>
    switch (reference.kind) {
      ReferenceKind.manuscript ||
      ReferenceKind.chapter ||
      ReferenceKind.scene =>
        CharacterWorkspaceDestination.manuscript,
      ReferenceKind.timeline => CharacterWorkspaceDestination.timeline,
      ReferenceKind.codex => CharacterWorkspaceDestination.codex,
      ReferenceKind.plot => CharacterWorkspaceDestination.plot,
      ReferenceKind.world => CharacterWorkspaceDestination.world,
      _ => null,
    };

class _CharacterOverview extends StatelessWidget {
  const _CharacterOverview({
    required this.character,
    required this.onSectionChanged,
  });
  final CharacterStudioRecord character;
  final ValueChanged<String> onSectionChanged;

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
          children: highlights.indexed
              .map((entry) => SizedBox(
                    width: 260,
                    child: InkWell(
                      onTap: () => onSectionChanged(
                        const [
                          'Goals and motivations',
                          'Goals and motivations',
                          'Psychology',
                          'Character arcs'
                        ][entry.$1],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: _DataField(
                        label: entry.$2.key,
                        value:
                            entry.$2.value.isEmpty ? 'Not set' : entry.$2.value,
                      ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: size,
        child: LocalImage(
          path: character.portraitPath,
          fallback: ColoredBox(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.person_rounded,
                size: size * .5,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
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
    'Main Character',
    'Antagonist',
    'Supporting Character',
    'Romance Character',
    'Villain',
    'Hero',
    'POV Character',
    'Fae Character',
    'Fantasy Character',
    'Modern Character',
    'Historical Character',
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
      for (final field in CharacterRecordTypes.character.fields)
        field.id: TextEditingController(
          text: widget.existing?.fields[field.id] ??
              _characterDisplayValue(field.defaultValue),
        ),
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
    final definition = _characterTemplate(template);
    final sections = _characterTemplateSections(template);
    final activeSection = sections
            .where((section) => section.title == editorSection)
            .firstOrNull ??
        sections.first;
    if (editorSection != activeSection.title) {
      editorSection = activeSection.title;
    }
    final fieldsById = {for (final field in definition.fields) field.id: field};
    final fields = activeSection.fieldIds
        .map((fieldId) => fieldsById[fieldId])
        .whereType<RecordFieldDefinition>()
        .where((field) => !field.hidden)
        .toList()
      ..sort((left, right) => left.order.compareTo(right.order));
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
                    onChanged: (value) => setState(() {
                      template = value ?? template;
                      editorSection =
                          _characterTemplateSections(template).first.title;
                    }),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: sections
                      .map((item) => ButtonSegment(
                          value: item.title, label: Text(item.title)))
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
                      if (activeSection.id == 'identity')
                        SizedBox(
                          width: 390,
                          child: TextField(
                              controller: controllers['identity.role'],
                              decoration: const InputDecoration(
                                  labelText: 'Story role')),
                        ),
                      ...fields.map((field) => SizedBox(
                            width: _isLongCharacterField(field) ? 792 : 390,
                            child: _CharacterFieldEditor(
                              definition: field,
                              controller: controllers[field.id]!,
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

bool _isLongCharacterField(RecordFieldDefinition field) => const {
      RecordFieldType.longText,
      RecordFieldType.richText,
      RecordFieldType.table,
      RecordFieldType.checklist,
    }.contains(field.type);

class _CharacterFieldEditor extends StatefulWidget {
  const _CharacterFieldEditor({
    required this.definition,
    required this.controller,
    this.issues = const [],
    this.onChanged,
  });

  final RecordFieldDefinition definition;
  final TextEditingController controller;
  final List<RecordValidationIssue> issues;
  final VoidCallback? onChanged;

  @override
  State<_CharacterFieldEditor> createState() => _CharacterFieldEditorState();
}

class _CharacterFieldEditorState extends State<_CharacterFieldEditor> {
  InputDecoration get decoration => InputDecoration(
        labelText: widget.definition.label,
        helperText: widget.definition.description.isEmpty
            ? null
            : widget.definition.description,
        suffixText: widget.definition.required ? 'Required' : null,
        errorText: widget.issues
            .where((issue) => issue.severity == RecordValidationSeverity.error)
            .map((issue) => issue.message)
            .firstOrNull,
      );

  @override
  Widget build(BuildContext context) {
    final field = widget.definition;
    if (field.type == RecordFieldType.table) {
      return _StructuredCharacterListEditor(
        definition: field,
        controller: widget.controller,
        onChanged: widget.onChanged,
      );
    }
    if (field.type == RecordFieldType.boolean) {
      final enabled = widget.controller.text.toLowerCase() == 'true';
      return SwitchListTile(
        key: Key('character-field-${field.id}'),
        value: enabled,
        title: Text(field.label),
        subtitle: field.description.isEmpty ? null : Text(field.description),
        onChanged: (value) => setState(
          () {
            widget.controller.text = value.toString();
            widget.onChanged?.call();
          },
        ),
      );
    }
    if (field.type == RecordFieldType.singleChoice) {
      final value = field.options.contains(widget.controller.text)
          ? widget.controller.text
          : null;
      return DropdownButtonFormField<String>(
        key: Key('character-field-${field.id}'),
        initialValue: value,
        decoration: decoration,
        items: field.options
            .map((option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ))
            .toList(),
        onChanged: (value) {
          widget.controller.text = value ?? '';
          widget.onChanged?.call();
        },
      );
    }
    final listLike = const {
      RecordFieldType.multipleChoice,
      RecordFieldType.tags,
      RecordFieldType.list,
      RecordFieldType.checklist,
      RecordFieldType.recordReference,
      RecordFieldType.relationship,
      RecordFieldType.timelineReference,
      RecordFieldType.locationReference,
      RecordFieldType.characterReference,
      RecordFieldType.plotThreadReference,
    }.contains(field.type);
    return TextField(
      key: field.id == 'identity.fullName'
          ? const Key('character-name-field')
          : Key('character-field-${field.id}'),
      controller: widget.controller,
      keyboardType: field.type == RecordFieldType.number ||
              field.type == RecordFieldType.rating
          ? const TextInputType.numberWithOptions(decimal: true)
          : field.type == RecordFieldType.date
              ? TextInputType.datetime
              : TextInputType.multiline,
      minLines: _isLongCharacterField(field) ? 3 : 1,
      maxLines: _isLongCharacterField(field) ? 7 : 1,
      decoration: decoration.copyWith(
        hintText: listLike
            ? 'Separate multiple values with commas'
            : field.type == RecordFieldType.table
                ? 'Enter a JSON list of structured items'
                : null,
      ),
      onChanged: (_) => widget.onChanged?.call(),
      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
    );
  }
}

class _StructuredCharacterListEditor extends StatefulWidget {
  const _StructuredCharacterListEditor({
    required this.definition,
    required this.controller,
    this.onChanged,
  });

  final RecordFieldDefinition definition;
  final TextEditingController controller;
  final VoidCallback? onChanged;

  @override
  State<_StructuredCharacterListEditor> createState() =>
      _StructuredCharacterListEditorState();
}

class _StructuredCharacterListEditorState
    extends State<_StructuredCharacterListEditor> {
  late List<Map<String, Object?>> items;

  @override
  void initState() {
    super.initState();
    items = _decodeItems(widget.controller.text);
  }

  List<Map<String, Object?>> _decodeItems(String value) {
    if (value.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, Object?>.from(item))
            .toList();
      }
    } on FormatException {
      return [];
    }
    return [];
  }

  void _commit() {
    widget.controller.text = jsonEncode(items);
    widget.onChanged?.call();
  }

  ({String key, String label, String secondaryKey}) get _shape =>
      switch (widget.definition.id) {
        'goals.entries' => (
            key: 'goal',
            label: 'Goal',
            secondaryKey: 'motivation'
          ),
        'arcs.entries' => (
            key: 'type',
            label: 'Arc',
            secondaryKey: 'startingState'
          ),
        'secrets.entries' => (
            key: 'secret',
            label: 'Secret',
            secondaryKey: 'consequence'
          ),
        'knowledge.entries' => (
            key: 'subject',
            label: 'Subject',
            secondaryKey: 'state'
          ),
        _ => (key: 'title', label: 'Item', secondaryKey: 'notes'),
      };

  Future<void> _edit([int? index]) async {
    final current = index == null ? const <String, Object?>{} : items[index];
    final title = TextEditingController(
      text: current[_shape.key]?.toString() ?? '',
    );
    final details = TextEditingController(
      text: current[_shape.secondaryKey]?.toString() ?? '',
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            index == null ? 'Add ${_shape.label}' : 'Edit ${_shape.label}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('structured-character-item-title'),
                  controller: title,
                  decoration: InputDecoration(labelText: _shape.label),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: details,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: _labelForPath(_shape.secondaryKey),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context, title.text.trim().isNotEmpty);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final next = <String, Object?>{
        ...current,
        _shape.key: title.text.trim(),
        if (details.text.trim().isNotEmpty)
          _shape.secondaryKey: details.text.trim(),
        'status': current['status'] ?? 'Active',
      };
      setState(() {
        if (index == null) {
          items.add(next);
        } else {
          items[index] = next;
        }
        _commit();
      });
    }
  }

  void _move(int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= items.length) return;
    setState(() {
      final item = items.removeAt(index);
      items.insert(target, item);
      _commit();
    });
  }

  void _toggleArchive(int index) {
    setState(() {
      final item = items[index];
      items[index] = {
        ...item,
        'status': item['status'] == 'Archived' ? 'Active' : 'Archived',
      };
      _commit();
    });
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.definition.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  key: Key('add-${widget.definition.id}'),
                  tooltip: 'Add ${_shape.label}',
                  onPressed: _edit,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (items.isEmpty)
              Text('No ${widget.definition.label.toLowerCase()} yet.')
            else
              ...items.indexed.map((entry) {
                final item = entry.$2;
                final archived = item['status'] == 'Archived';
                return ListTile(
                  key: Key('${widget.definition.id}-${entry.$1}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item[_shape.key]?.toString() ?? _shape.label,
                    style: TextStyle(
                      decoration: archived ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
                    item[_shape.secondaryKey]?.toString() ??
                        item['status']?.toString() ??
                        '',
                  ),
                  onTap: () => _edit(entry.$1),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Move up',
                        onPressed:
                            entry.$1 == 0 ? null : () => _move(entry.$1, -1),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                      IconButton(
                        tooltip: 'Move down',
                        onPressed: entry.$1 == items.length - 1
                            ? null
                            : () => _move(entry.$1, 1),
                        icon: const Icon(Icons.arrow_downward_rounded),
                      ),
                      IconButton(
                        tooltip: archived ? 'Restore' : 'Archive',
                        onPressed: () => _toggleArchive(entry.$1),
                        icon: Icon(archived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      );
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
