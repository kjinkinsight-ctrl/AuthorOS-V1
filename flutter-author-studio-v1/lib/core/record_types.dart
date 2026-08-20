import 'record_scope.dart';

enum RecordFieldType {
  shortText,
  longText,
  number,
  date,
  dateRange,
  boolean,
  singleChoice,
  multipleChoice,
  tags,
  rating,
  image,
  fileReference,
  recordReference,
  relationship,
  richText,
  list,
  table,
  timelineReference,
  locationReference,
  characterReference,
  plotThreadReference,
  url,
  checklist,
}

class RecordFieldDefinition {
  const RecordFieldDefinition({
    required this.id,
    required this.label,
    required this.type,
    required this.order,
    this.description = '',
    this.required = false,
    this.hidden = false,
    this.defaultValue,
    this.options = const [],
    this.referenceTypeIds = const [],
    this.extensionData = const {},
  });

  final String id;
  final String label;
  final RecordFieldType type;
  final int order;
  final String description;
  final bool required;
  final bool hidden;
  final Object? defaultValue;
  final List<String> options;
  final List<String> referenceTypeIds;
  final Map<String, Object?> extensionData;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        'order': order,
        'description': description,
        'required': required,
        'hidden': hidden,
        'defaultValue': defaultValue,
        'options': options,
        'referenceTypeIds': referenceTypeIds,
        'extensionData': extensionData,
      };

  factory RecordFieldDefinition.fromJson(Map<String, dynamic> json) =>
      RecordFieldDefinition(
        id: _requiredString(json['id'], 'Field id'),
        label: _requiredString(json['label'], 'Field label'),
        type: _enumValue(RecordFieldType.values, json['type'], 'field type'),
        order: _nonNegativeInt(json['order'], 'Field order'),
        description: json['description'] as String? ?? '',
        required: json['required'] as bool? ?? false,
        hidden: json['hidden'] as bool? ?? false,
        defaultValue: json['defaultValue'],
        options: _stringList(json['options']),
        referenceTypeIds: _stringList(json['referenceTypeIds']),
        extensionData: _objectMap(json['extensionData']),
      );
}

class RecordTemplateSection {
  const RecordTemplateSection({
    required this.id,
    required this.title,
    required this.order,
    this.fieldIds = const [],
    this.collapsedByDefault = false,
    this.extensionData = const {},
  });

  final String id;
  final String title;
  final int order;
  final List<String> fieldIds;
  final bool collapsedByDefault;
  final Map<String, Object?> extensionData;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'order': order,
        'fieldIds': fieldIds,
        'collapsedByDefault': collapsedByDefault,
        'extensionData': extensionData,
      };

  factory RecordTemplateSection.fromJson(Map<String, dynamic> json) =>
      RecordTemplateSection(
        id: _requiredString(json['id'], 'Section id'),
        title: _requiredString(json['title'], 'Section title'),
        order: _nonNegativeInt(json['order'], 'Section order'),
        fieldIds: _stringList(json['fieldIds']),
        collapsedByDefault: json['collapsedByDefault'] as bool? ?? false,
        extensionData: _objectMap(json['extensionData']),
      );
}

class RecordTypeDefinition {
  const RecordTypeDefinition({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.fields,
    required this.sections,
    this.description = '',
    this.icon = 'description',
    this.baseTypeId,
    this.tags = const [],
    this.suggestedLinkTypeIds = const [],
    this.scopeType = RecordScopeType.library,
    this.scopeId = 'authoros',
    this.allowedScopeTypes = RecordScopeType.values,
    this.permissions = const {},
    this.exportBehavior = const {},
    this.templateVersion = 1,
    this.builtIn = false,
    this.sourcePackId,
    this.extensionData = const {},
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final String categoryId;
  final String? baseTypeId;
  final List<RecordFieldDefinition> fields;
  final List<RecordTemplateSection> sections;
  final List<String> tags;
  final List<String> suggestedLinkTypeIds;
  final RecordScopeType scopeType;
  final String scopeId;
  final List<RecordScopeType> allowedScopeTypes;
  final Map<String, Object?> permissions;
  final Map<String, Object?> exportBehavior;
  final int templateVersion;
  final bool builtIn;
  final String? sourcePackId;
  final Map<String, Object?> extensionData;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'categoryId': categoryId,
        'baseTypeId': baseTypeId,
        'fields': fields.map((field) => field.toJson()).toList(),
        'sections': sections.map((section) => section.toJson()).toList(),
        'tags': tags,
        'suggestedLinkTypeIds': suggestedLinkTypeIds,
        'scopeType': scopeType.name,
        'scopeId': scopeId,
        'allowedScopeTypes':
            allowedScopeTypes.map((scope) => scope.name).toList(),
        'permissions': permissions,
        'exportBehavior': exportBehavior,
        'templateVersion': templateVersion,
        'builtIn': builtIn,
        'sourcePackId': sourcePackId,
        'extensionData': extensionData,
      };

  factory RecordTypeDefinition.fromJson(Map<String, dynamic> json) =>
      RecordTypeDefinition(
        id: _requiredString(json['id'], 'Record type id'),
        name: _requiredString(json['name'], 'Record type name'),
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? 'description',
        categoryId: _requiredString(json['categoryId'], 'Category id'),
        baseTypeId: _optionalString(json['baseTypeId']),
        fields: _mapList(json['fields'])
            .map(RecordFieldDefinition.fromJson)
            .toList(),
        sections: _mapList(json['sections'])
            .map(RecordTemplateSection.fromJson)
            .toList(),
        tags: _stringList(json['tags']),
        suggestedLinkTypeIds: _stringList(json['suggestedLinkTypeIds']),
        scopeType: _enumValue(
          RecordScopeType.values,
          json['scopeType'] ?? RecordScopeType.library.name,
          'definition scope',
        ),
        scopeId: _requiredString(
          json['scopeId'] ?? 'authoros',
          'Definition scope id',
        ),
        allowedScopeTypes: _stringList(json['allowedScopeTypes'])
            .map((value) =>
                _enumValue(RecordScopeType.values, value, 'record scope'))
            .toList(),
        permissions: _objectMap(json['permissions']),
        exportBehavior: _objectMap(json['exportBehavior']),
        templateVersion:
            _positiveInt(json['templateVersion'], 'Template version'),
        builtIn: json['builtIn'] as bool? ?? false,
        sourcePackId: _optionalString(json['sourcePackId']),
        extensionData: _objectMap(json['extensionData']),
      );
}

class RecordTypeRegistry {
  RecordTypeRegistry(Iterable<RecordTypeDefinition> definitions)
      : _definitions = {
          for (final definition in definitions) definition.id: definition,
        } {
    if (_definitions.length != definitions.length) {
      throw const FormatException('Record type ids must be unique.');
    }
    for (final definition in _definitions.values) {
      _validateDefinition(definition);
    }
  }

  final Map<String, RecordTypeDefinition> _definitions;

  List<RecordTypeDefinition> get definitions => _definitions.values.toList()
    ..sort((left, right) => left.id.compareTo(right.id));

  RecordTypeDefinition resolve(String id) => _resolve(id, <String>[]);

  bool isTemplateCompatible(String templateId, String recordTypeId) {
    String? currentId = templateId;
    final visited = <String>{};
    while (currentId != null && visited.add(currentId)) {
      if (currentId == recordTypeId) return true;
      currentId = _definitions[currentId]?.baseTypeId;
    }
    return false;
  }

  RecordTypeDefinition _resolve(String id, List<String> path) {
    final definition = _definitions[id];
    if (definition == null) {
      throw StateError('Unknown record type: $id');
    }
    if (path.contains(id)) {
      throw StateError(
        'Record type inheritance cycle: ${[...path, id].join(' -> ')}',
      );
    }
    final baseTypeId = definition.baseTypeId;
    if (baseTypeId == null) {
      return definition;
    }
    final parent = _resolve(baseTypeId, [...path, id]);
    return _merge(parent, definition);
  }

  RecordTypeDefinition _merge(
    RecordTypeDefinition parent,
    RecordTypeDefinition child,
  ) {
    final fields = <String, RecordFieldDefinition>{
      for (final field in parent.fields) field.id: field,
    };
    for (final field in child.fields) {
      final inherited = fields[field.id];
      if (field.hidden && inherited?.required == true) {
        throw StateError('Required field ${field.id} cannot be hidden.');
      }
      fields[field.id] = field;
    }

    final sections = <String, RecordTemplateSection>{
      for (final section in parent.sections) section.id: section,
      for (final section in child.sections) section.id: section,
    };
    final merged = RecordTypeDefinition(
      id: child.id,
      name: child.name,
      description:
          child.description.isEmpty ? parent.description : child.description,
      icon: child.icon,
      categoryId: child.categoryId,
      baseTypeId: child.baseTypeId,
      fields: fields.values.toList()
        ..sort((left, right) => left.order.compareTo(right.order)),
      sections: sections.values.toList()
        ..sort((left, right) => left.order.compareTo(right.order)),
      tags: {...parent.tags, ...child.tags}.toList(),
      suggestedLinkTypeIds: {
        ...parent.suggestedLinkTypeIds,
        ...child.suggestedLinkTypeIds,
      }.toList(),
      scopeType: child.scopeType,
      scopeId: child.scopeId,
      allowedScopeTypes: child.allowedScopeTypes,
      permissions: {...parent.permissions, ...child.permissions},
      exportBehavior: {...parent.exportBehavior, ...child.exportBehavior},
      templateVersion: child.templateVersion,
      builtIn: child.builtIn,
      sourcePackId: child.sourcePackId ?? parent.sourcePackId,
      extensionData: {...parent.extensionData, ...child.extensionData},
    );
    _validateDefinition(merged);
    return merged;
  }

  void _validateDefinition(RecordTypeDefinition definition) {
    _requiredString(definition.id, 'Record type id');
    _requiredString(definition.name, 'Record type name');
    _requiredString(definition.categoryId, 'Category id');
    _requiredString(definition.scopeId, 'Definition scope id');
    if (definition.templateVersion < 1) {
      throw const FormatException('Template version must be positive.');
    }
    if (definition.allowedScopeTypes.isEmpty) {
      throw FormatException(
        'Record type ${definition.id} must allow at least one scope.',
      );
    }

    final fieldIds = <String>{};
    for (final field in definition.fields) {
      if (!fieldIds.add(field.id)) {
        throw FormatException('Duplicate field id: ${field.id}');
      }
      _requiredString(field.id, 'Field id');
      _requiredString(field.label, 'Field label');
      if (field.order < 0) {
        throw FormatException('Field ${field.id} has a negative order.');
      }
      if (field.required && field.hidden) {
        throw FormatException('Required field ${field.id} cannot be hidden.');
      }
      if ((field.type == RecordFieldType.singleChoice ||
              field.type == RecordFieldType.multipleChoice) &&
          field.options.isEmpty) {
        throw FormatException('Choice field ${field.id} requires options.');
      }
      _validateDefault(field);
    }

    final sectionIds = <String>{};
    for (final section in definition.sections) {
      if (!sectionIds.add(section.id)) {
        throw FormatException('Duplicate section id: ${section.id}');
      }
      if (section.order < 0) {
        throw FormatException('Section ${section.id} has a negative order.');
      }
      for (final fieldId in section.fieldIds) {
        if (!fieldIds.contains(fieldId)) {
          throw FormatException(
            'Section ${section.id} references unknown field $fieldId.',
          );
        }
      }
    }
  }
}

void _validateDefault(RecordFieldDefinition field) {
  final value = field.defaultValue;
  if (value == null) {
    return;
  }
  final valid = switch (field.type) {
    RecordFieldType.number || RecordFieldType.rating => value is num,
    RecordFieldType.boolean => value is bool,
    RecordFieldType.multipleChoice ||
    RecordFieldType.tags ||
    RecordFieldType.list ||
    RecordFieldType.table ||
    RecordFieldType.checklist =>
      value is List,
    RecordFieldType.singleChoice =>
      value is String && field.options.contains(value),
    _ => value is String,
  };
  if (!valid) {
    throw FormatException('Invalid default value for field ${field.id}.');
  }
}

String _requiredString(Object? value, String label) {
  final normalized = value is String ? value.trim() : '';
  if (normalized.isEmpty) {
    throw FormatException('$label is required.');
  }
  return normalized;
}

String? _optionalString(Object? value) {
  final normalized = value is String ? value.trim() : '';
  return normalized.isEmpty ? null : normalized;
}

int _positiveInt(Object? value, String label) {
  final number = value is num ? value.toInt() : int.tryParse('$value');
  if (number == null || number < 1) {
    throw FormatException('$label must be a positive integer.');
  }
  return number;
}

int _nonNegativeInt(Object? value, String label) {
  final number = value is num ? value.toInt() : int.tryParse('$value');
  if (number == null || number < 0) {
    throw FormatException('$label must be a non-negative integer.');
  }
  return number;
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, String label) {
  for (final value in values) {
    if (value.name == raw) {
      return value;
    }
  }
  throw FormatException('Unknown $label: $raw');
}

Map<String, Object?> _objectMap(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, Object?>{};

List<String> _stringList(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : [];

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value.map((item) => Map<String, dynamic>.from(item as Map)).toList()
    : [];
