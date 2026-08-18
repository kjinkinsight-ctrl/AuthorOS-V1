enum RecordScopeType { library, universe, series, project, manuscript }

enum AuthorRecordStatus { active, archived, deleted }

enum RecordLinkDirection { directed, undirected }

class AuthorOsFeatureFlags {
  const AuthorOsFeatureFlags._();

  static const connectedDomain = bool.fromEnvironment(
    'AUTHOROS_CONNECTED_DOMAIN',
    defaultValue: false,
  );
}

class AuthorRecord {
  const AuthorRecord({
    required this.id,
    required this.typeId,
    required this.scopeType,
    required this.scopeId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.status = AuthorRecordStatus.active,
    this.schemaVersion = 1,
    this.revision = 1,
    this.fields = const {},
    this.tags = const [],
    this.extensionData = const {},
  });

  final String id;
  final String typeId;
  final RecordScopeType scopeType;
  final String scopeId;
  final String title;
  final AuthorRecordStatus status;
  final int schemaVersion;
  final int revision;
  final Map<String, Object?> fields;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, Object?> extensionData;

  AuthorRecord copyWith({
    String? title,
    AuthorRecordStatus? status,
    int? revision,
    Map<String, Object?>? fields,
    List<String>? tags,
    DateTime? updatedAt,
  }) =>
      AuthorRecord(
        id: id,
        typeId: typeId,
        scopeType: scopeType,
        scopeId: scopeId,
        title: title ?? this.title,
        status: status ?? this.status,
        schemaVersion: schemaVersion,
        revision: revision ?? this.revision,
        fields: fields ?? this.fields,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        extensionData: extensionData,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'typeId': typeId,
        'scopeType': scopeType.name,
        'scopeId': scopeId,
        'title': title,
        'status': status.name,
        'schemaVersion': schemaVersion,
        'revision': revision,
        'fields': fields,
        'tags': tags,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'extensionData': extensionData,
      };

  factory AuthorRecord.fromJson(Map<String, dynamic> json) => AuthorRecord(
        id: _requiredString(json['id'], 'Record id'),
        typeId: _requiredString(json['typeId'], 'Record type id'),
        scopeType: _enumValue(
          RecordScopeType.values,
          json['scopeType'],
          'record scope',
        ),
        scopeId: _requiredString(json['scopeId'], 'Record scope id'),
        title: _requiredString(json['title'], 'Record title'),
        status: _enumValue(
          AuthorRecordStatus.values,
          json['status'] ?? AuthorRecordStatus.active.name,
          'record status',
        ),
        schemaVersion: _positiveInt(json['schemaVersion']),
        revision: _positiveInt(json['revision']),
        fields: _objectMap(json['fields']),
        tags: _stringList(json['tags']),
        createdAt: _requiredDate(json['createdAt'], 'Record createdAt'),
        updatedAt: _requiredDate(json['updatedAt'], 'Record updatedAt'),
        extensionData: _objectMap(json['extensionData']),
      );
}

class ManuscriptNodeReference {
  const ManuscriptNodeReference({
    required this.id,
    required this.projectId,
    required this.nodeType,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.revision = 1,
    this.extensionData = const {},
  });

  final String id;
  final String projectId;
  final String nodeType;
  final String title;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, Object?> extensionData;

  Map<String, Object?> toJson() => {
        'id': id,
        'projectId': projectId,
        'nodeType': nodeType,
        'title': title,
        'revision': revision,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'extensionData': extensionData,
      };

  factory ManuscriptNodeReference.fromJson(Map<String, dynamic> json) =>
      ManuscriptNodeReference(
        id: _requiredString(json['id'], 'Manuscript node id'),
        projectId: _requiredString(json['projectId'], 'Node project id'),
        nodeType: _requiredString(json['nodeType'], 'Manuscript node type'),
        title: _requiredString(json['title'], 'Manuscript node title'),
        revision: _positiveInt(json['revision']),
        createdAt: _requiredDate(json['createdAt'], 'Node createdAt'),
        updatedAt: _requiredDate(json['updatedAt'], 'Node updatedAt'),
        extensionData: _objectMap(json['extensionData']),
      );
}

class RecordLink {
  const RecordLink({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.typeId,
    required this.scopeId,
    required this.createdAt,
    required this.updatedAt,
    this.direction = RecordLinkDirection.directed,
    this.label = '',
    this.revision = 1,
    this.metadata = const {},
    this.extensionData = const {},
  });

  final String id;
  final String sourceId;
  final String targetId;
  final String typeId;
  final String scopeId;
  final RecordLinkDirection direction;
  final String label;
  final int revision;
  final Map<String, Object?> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, Object?> extensionData;

  Map<String, Object?> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'targetId': targetId,
        'typeId': typeId,
        'scopeId': scopeId,
        'direction': direction.name,
        'label': label,
        'revision': revision,
        'metadata': metadata,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'extensionData': extensionData,
      };

  factory RecordLink.fromJson(Map<String, dynamic> json) => RecordLink(
        id: _requiredString(json['id'], 'Link id'),
        sourceId: _requiredString(json['sourceId'], 'Link source id'),
        targetId: _requiredString(json['targetId'], 'Link target id'),
        typeId: _requiredString(json['typeId'], 'Link type id'),
        scopeId: _requiredString(json['scopeId'], 'Link scope id'),
        direction: _enumValue(
          RecordLinkDirection.values,
          json['direction'] ?? RecordLinkDirection.directed.name,
          'link direction',
        ),
        label: json['label'] as String? ?? '',
        revision: _positiveInt(json['revision']),
        metadata: _objectMap(json['metadata']),
        createdAt: _requiredDate(json['createdAt'], 'Link createdAt'),
        updatedAt: _requiredDate(json['updatedAt'], 'Link updatedAt'),
        extensionData: _objectMap(json['extensionData']),
      );
}

class ConnectedDomainSnapshot {
  const ConnectedDomainSnapshot({
    required this.records,
    required this.manuscriptNodes,
    required this.links,
  });

  final List<AuthorRecord> records;
  final List<ManuscriptNodeReference> manuscriptNodes;
  final List<RecordLink> links;

  Map<String, Object?> toJson() => {
        'schemaVersion': 1,
        'records': records.map((record) => record.toJson()).toList(),
        'manuscriptNodes':
            manuscriptNodes.map((node) => node.toJson()).toList(),
        'links': links.map((link) => link.toJson()).toList(),
      };

  factory ConnectedDomainSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported connected-domain snapshot.');
    }
    return ConnectedDomainSnapshot(
      records: _mapList(json['records']).map(AuthorRecord.fromJson).toList(),
      manuscriptNodes: _mapList(json['manuscriptNodes'])
          .map(ManuscriptNodeReference.fromJson)
          .toList(),
      links: _mapList(json['links']).map(RecordLink.fromJson).toList(),
    );
  }
}

class InMemoryConnectedDomainRepository {
  InMemoryConnectedDomainRepository({ConnectedDomainSnapshot? initial}) {
    if (initial != null) {
      _replaceWith(initial);
      _validateState(_records, _manuscriptNodes, _links);
    }
  }

  final Map<String, AuthorRecord> _records = {};
  final Map<String, ManuscriptNodeReference> _manuscriptNodes = {};
  final Map<String, RecordLink> _links = {};

  T transaction<T>(T Function(ConnectedDomainTransaction transaction) action) {
    final records = Map<String, AuthorRecord>.from(_records);
    final manuscriptNodes =
        Map<String, ManuscriptNodeReference>.from(_manuscriptNodes);
    final links = Map<String, RecordLink>.from(_links);
    final transaction = ConnectedDomainTransaction._(
      records,
      manuscriptNodes,
      links,
    );
    final result = action(transaction);
    _validateState(records, manuscriptNodes, links);
    _records
      ..clear()
      ..addAll(records);
    _manuscriptNodes
      ..clear()
      ..addAll(manuscriptNodes);
    _links
      ..clear()
      ..addAll(links);
    return result;
  }

  AuthorRecord? recordById(String id) => _records[id];

  ManuscriptNodeReference? manuscriptNodeById(String id) =>
      _manuscriptNodes[id];

  List<RecordLink> backlinks(String entityId) => _links.values
      .where((link) => link.sourceId == entityId || link.targetId == entityId)
      .toList()
    ..sort((left, right) => left.id.compareTo(right.id));

  ConnectedDomainSnapshot snapshot() => ConnectedDomainSnapshot(
        records: _records.values.toList()
          ..sort((left, right) => left.id.compareTo(right.id)),
        manuscriptNodes: _manuscriptNodes.values.toList()
          ..sort((left, right) => left.id.compareTo(right.id)),
        links: _links.values.toList()
          ..sort((left, right) => left.id.compareTo(right.id)),
      );

  void _replaceWith(ConnectedDomainSnapshot snapshot) {
    _records
        .addEntries(snapshot.records.map((value) => MapEntry(value.id, value)));
    _manuscriptNodes.addEntries(
      snapshot.manuscriptNodes.map((value) => MapEntry(value.id, value)),
    );
    _links.addEntries(snapshot.links.map((value) => MapEntry(value.id, value)));
  }
}

class ConnectedDomainTransaction {
  ConnectedDomainTransaction._(
    this._records,
    this._manuscriptNodes,
    this._links,
  );

  final Map<String, AuthorRecord> _records;
  final Map<String, ManuscriptNodeReference> _manuscriptNodes;
  final Map<String, RecordLink> _links;

  void putRecord(AuthorRecord record) {
    _validateIdentity(record.id, 'Record id');
    if (_manuscriptNodes.containsKey(record.id)) {
      throw StateError('Entity id ${record.id} is already a manuscript node.');
    }
    _records[record.id] = record;
  }

  void putManuscriptNode(ManuscriptNodeReference node) {
    _validateIdentity(node.id, 'Manuscript node id');
    if (_records.containsKey(node.id)) {
      throw StateError('Entity id ${node.id} is already a record.');
    }
    _manuscriptNodes[node.id] = node;
  }

  void putLink(RecordLink link) {
    _validateIdentity(link.id, 'Link id');
    _links[link.id] = link;
  }
}

void _validateState(
  Map<String, AuthorRecord> records,
  Map<String, ManuscriptNodeReference> manuscriptNodes,
  Map<String, RecordLink> links,
) {
  final entityIds = {...records.keys, ...manuscriptNodes.keys};
  for (final record in records.values) {
    _validateIdentity(record.id, 'Record id');
    _validateIdentity(record.typeId, 'Record type id');
    _validateIdentity(record.scopeId, 'Record scope id');
  }
  for (final node in manuscriptNodes.values) {
    _validateIdentity(node.id, 'Manuscript node id');
    _validateIdentity(node.projectId, 'Node project id');
  }
  for (final link in links.values) {
    _validateIdentity(link.id, 'Link id');
    _validateIdentity(link.typeId, 'Link type id');
    _validateIdentity(link.scopeId, 'Link scope id');
    if (!entityIds.contains(link.sourceId)) {
      throw StateError('Link ${link.id} has unknown source ${link.sourceId}.');
    }
    if (!entityIds.contains(link.targetId)) {
      throw StateError('Link ${link.id} has unknown target ${link.targetId}.');
    }
  }
}

void _validateIdentity(String value, String label) {
  if (value.trim().isEmpty) {
    throw StateError('$label must not be empty.');
  }
}

String _requiredString(Object? value, String label) {
  final normalized = value is String ? value.trim() : '';
  if (normalized.isEmpty) {
    throw FormatException('$label is required.');
  }
  return normalized;
}

int _positiveInt(Object? value) {
  final number = value is num ? value.toInt() : int.tryParse('$value');
  if (number == null || number < 1) {
    throw const FormatException('Expected a positive integer.');
  }
  return number;
}

DateTime _requiredDate(Object? value, String label) {
  final parsed = DateTime.tryParse(value is String ? value : '');
  if (parsed == null) {
    throw FormatException('$label is invalid.');
  }
  return parsed;
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
