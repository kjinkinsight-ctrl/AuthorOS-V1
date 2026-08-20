import 'record_types.dart';

enum ConnectionDirection { directed, undirected }

enum ConnectionCardinality { oneToOne, oneToMany, manyToOne, manyToMany }

class ConnectionTypeDefinition {
  const ConnectionTypeDefinition({
    required this.id,
    required this.displayName,
    required this.sourceTypeIds,
    required this.targetTypeIds,
    required this.inverseLabel,
    this.direction = ConnectionDirection.directed,
    this.cardinality = ConnectionCardinality.manyToMany,
    this.metadataFields = const [],
    this.temporalSupport = false,
    this.builtIn = false,
    this.scopeId = 'authoros',
    this.sourcePackId,
    this.extensionData = const {},
  });

  final String id;
  final String displayName;
  final List<String> sourceTypeIds;
  final List<String> targetTypeIds;
  final ConnectionDirection direction;
  final String inverseLabel;
  final ConnectionCardinality cardinality;
  final List<RecordFieldDefinition> metadataFields;
  final bool temporalSupport;
  final bool builtIn;
  final String scopeId;
  final String? sourcePackId;
  final Map<String, Object?> extensionData;

  bool permits(String sourceTypeId, String targetTypeId) =>
      _permitsType(sourceTypeIds, sourceTypeId) &&
      _permitsType(targetTypeIds, targetTypeId);

  Map<String, Object?> toJson() => {
        'id': id,
        'displayName': displayName,
        'sourceTypeIds': sourceTypeIds,
        'targetTypeIds': targetTypeIds,
        'direction': direction.name,
        'inverseLabel': inverseLabel,
        'cardinality': cardinality.name,
        'metadataFields':
            metadataFields.map((field) => field.toJson()).toList(),
        'temporalSupport': temporalSupport,
        'builtIn': builtIn,
        'scopeId': scopeId,
        'sourcePackId': sourcePackId,
        'extensionData': extensionData,
      };

  factory ConnectionTypeDefinition.fromJson(Map<String, dynamic> json) =>
      ConnectionTypeDefinition(
        id: _requiredString(json['id'], 'Connection type id'),
        displayName:
            _requiredString(json['displayName'], 'Connection display name'),
        sourceTypeIds: _stringList(json['sourceTypeIds']),
        targetTypeIds: _stringList(json['targetTypeIds']),
        direction: _enumValue(
          ConnectionDirection.values,
          json['direction'] ?? ConnectionDirection.directed.name,
          'connection direction',
        ),
        inverseLabel:
            _requiredString(json['inverseLabel'], 'Connection inverse label'),
        cardinality: _enumValue(
          ConnectionCardinality.values,
          json['cardinality'] ?? ConnectionCardinality.manyToMany.name,
          'connection cardinality',
        ),
        metadataFields: _mapList(json['metadataFields'])
            .map(RecordFieldDefinition.fromJson)
            .toList(),
        temporalSupport: json['temporalSupport'] as bool? ?? false,
        builtIn: json['builtIn'] as bool? ?? false,
        scopeId: _requiredString(
          json['scopeId'] ?? 'authoros',
          'Connection definition scope id',
        ),
        sourcePackId: _optionalString(json['sourcePackId']),
        extensionData: _objectMap(json['extensionData']),
      );
}

class ConnectionTypeRegistry {
  ConnectionTypeRegistry(Iterable<ConnectionTypeDefinition> definitions)
      : _definitions = {
          for (final definition in definitions) definition.id: definition,
        } {
    if (_definitions.length != definitions.length) {
      throw const FormatException('Connection type ids must be unique.');
    }
    for (final definition in _definitions.values) {
      _validateDefinition(definition);
    }
  }

  final Map<String, ConnectionTypeDefinition> _definitions;

  List<ConnectionTypeDefinition> get definitions => _definitions.values.toList()
    ..sort((left, right) => left.id.compareTo(right.id));

  ConnectionTypeDefinition resolve(String id) {
    final definition = _definitions[id];
    if (definition == null) {
      throw StateError('Unknown connection type: $id');
    }
    return definition;
  }

  void validateConnection({
    required String typeId,
    required String sourceTypeId,
    required String targetTypeId,
    Map<String, Object?> metadata = const {},
  }) {
    final definition = resolve(typeId);
    if (!definition.permits(sourceTypeId, targetTypeId)) {
      throw StateError(
        '$typeId does not permit $sourceTypeId -> $targetTypeId.',
      );
    }
    _validateMetadata(definition, metadata);
  }

  void _validateDefinition(ConnectionTypeDefinition definition) {
    _requiredString(definition.id, 'Connection type id');
    _requiredString(definition.displayName, 'Connection display name');
    _requiredString(definition.inverseLabel, 'Connection inverse label');
    _requiredString(definition.scopeId, 'Connection definition scope id');
    if (definition.sourceTypeIds.isEmpty || definition.targetTypeIds.isEmpty) {
      throw FormatException(
        'Connection type ${definition.id} requires source and target types.',
      );
    }
    final fieldIds = <String>{};
    for (final field in definition.metadataFields) {
      if (!fieldIds.add(field.id)) {
        throw FormatException('Duplicate metadata field id: ${field.id}');
      }
    }
  }

  void _validateMetadata(
    ConnectionTypeDefinition definition,
    Map<String, Object?> metadata,
  ) {
    final fields = {
      for (final field in definition.metadataFields) field.id: field,
    };
    for (final key in metadata.keys) {
      if (!fields.containsKey(key)) {
        throw StateError('Unknown metadata field $key for ${definition.id}.');
      }
    }
    for (final field in fields.values) {
      if (field.required && !metadata.containsKey(field.id)) {
        throw StateError(
          'Required metadata field ${field.id} is missing for ${definition.id}.',
        );
      }
    }
  }
}

bool _permitsType(List<String> allowedTypes, String typeId) =>
    allowedTypes.contains('*') || allowedTypes.contains(typeId);

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
