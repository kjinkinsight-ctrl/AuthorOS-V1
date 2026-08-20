import 'dart:collection';

enum VersionEntityKind {
  record,
  connection,
  branch,
  branchRecord,
  branchConnection,
}

enum AuditChangeType {
  created,
  updated,
  renamed,
  archived,
  restored,
  deleted,
  duplicated,
  connectionAdded,
  connectionRemoved,
  connectionMetadataChanged,
  connectionTypeChanged,
  templateChanged,
  statusChanged,
  scopeChanged,
  branchChanged,
}

class RecordVersion {
  RecordVersion({
    required this.id,
    required this.entityId,
    required this.entityKind,
    required this.recordId,
    required this.recordType,
    required this.projectId,
    required this.createdAt,
    required this.changeType,
    required this.summary,
    required this.schemaVersion,
    required Map<String, Object?> snapshot,
    this.seriesId,
    this.bookId,
    this.branchId,
    this.previousVersionId,
    this.source = 'authoros',
    Map<String, Object?> metadata = const {},
  })  : snapshot = UnmodifiableMapView(_deepCopyMap(snapshot)),
        metadata = UnmodifiableMapView(_deepCopyMap(metadata));

  final String id;
  final String entityId;
  final VersionEntityKind entityKind;
  final String recordId;
  final String recordType;
  final String projectId;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final DateTime createdAt;
  final AuditChangeType changeType;
  final String summary;
  final int schemaVersion;
  final String? previousVersionId;
  final String source;
  final Map<String, Object?> snapshot;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
        'id': id,
        'entityId': entityId,
        'entityKind': entityKind.name,
        'recordId': recordId,
        'recordType': recordType,
        'projectId': projectId,
        'seriesId': seriesId,
        'bookId': bookId,
        'branchId': branchId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'changeType': changeType.name,
        'summary': summary,
        'schemaVersion': schemaVersion,
        'previousVersionId': previousVersionId,
        'source': source,
        'snapshot': _deepCopyMap(snapshot),
        'metadata': _deepCopyMap(metadata),
      };

  factory RecordVersion.fromJson(Map<String, dynamic> json) => RecordVersion(
        id: _requiredString(json['id'], 'Version id'),
        entityId: _requiredString(json['entityId'], 'Version entity id'),
        entityKind: _enumValue(
          VersionEntityKind.values,
          json['entityKind'],
          'version entity kind',
        ),
        recordId: _requiredString(json['recordId'], 'Version record id'),
        recordType: _requiredString(json['recordType'], 'Version record type'),
        projectId: _requiredString(json['projectId'], 'Version project id'),
        seriesId: _optionalString(json['seriesId']),
        bookId: _optionalString(json['bookId']),
        branchId: _optionalString(json['branchId']),
        createdAt: _requiredDate(json['createdAt'], 'Version createdAt'),
        changeType: _enumValue(
          AuditChangeType.values,
          json['changeType'],
          'version change type',
        ),
        summary: _requiredString(json['summary'], 'Version summary'),
        schemaVersion: _positiveInt(json['schemaVersion'], 'Schema version'),
        previousVersionId: _optionalString(json['previousVersionId']),
        source: _requiredString(json['source'] ?? 'authoros', 'Version source'),
        snapshot: _objectMap(json['snapshot']),
        metadata: _objectMap(json['metadata']),
      );
}

class AuditEvent {
  AuditEvent({
    required this.id,
    required this.versionId,
    required this.entityId,
    required this.entityKind,
    required this.recordId,
    required this.recordType,
    required this.projectId,
    required this.createdAt,
    required this.changeType,
    required this.summary,
    this.seriesId,
    this.bookId,
    this.branchId,
    this.source = 'authoros',
    Map<String, Object?> metadata = const {},
  }) : metadata = UnmodifiableMapView(_deepCopyMap(metadata));

  final String id;
  final String versionId;
  final String entityId;
  final VersionEntityKind entityKind;
  final String recordId;
  final String recordType;
  final String projectId;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final DateTime createdAt;
  final AuditChangeType changeType;
  final String summary;
  final String source;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
        'id': id,
        'versionId': versionId,
        'entityId': entityId,
        'entityKind': entityKind.name,
        'recordId': recordId,
        'recordType': recordType,
        'projectId': projectId,
        'seriesId': seriesId,
        'bookId': bookId,
        'branchId': branchId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'changeType': changeType.name,
        'summary': summary,
        'source': source,
        'metadata': _deepCopyMap(metadata),
      };

  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
        id: _requiredString(json['id'], 'Audit event id'),
        versionId: _requiredString(json['versionId'], 'Audit version id'),
        entityId: _requiredString(json['entityId'], 'Audit entity id'),
        entityKind: _enumValue(
          VersionEntityKind.values,
          json['entityKind'],
          'audit entity kind',
        ),
        recordId: _requiredString(json['recordId'], 'Audit record id'),
        recordType: _requiredString(json['recordType'], 'Audit record type'),
        projectId: _requiredString(json['projectId'], 'Audit project id'),
        seriesId: _optionalString(json['seriesId']),
        bookId: _optionalString(json['bookId']),
        branchId: _optionalString(json['branchId']),
        createdAt: _requiredDate(json['createdAt'], 'Audit createdAt'),
        changeType: _enumValue(
          AuditChangeType.values,
          json['changeType'],
          'audit change type',
        ),
        summary: _requiredString(json['summary'], 'Audit summary'),
        source: _requiredString(json['source'] ?? 'authoros', 'Audit source'),
        metadata: _objectMap(json['metadata']),
      );
}

class HistoryFilter {
  const HistoryFilter({
    required this.projectId,
    this.recordId,
    this.recordType,
    this.seriesId,
    this.bookId,
    this.branchId,
    this.changeType,
    this.from,
    this.to,
    this.limit = 500,
  });

  final String projectId;
  final String? recordId;
  final String? recordType;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final AuditChangeType? changeType;
  final DateTime? from;
  final DateTime? to;
  final int limit;
}

Map<String, Object?> _deepCopyMap(Map<dynamic, dynamic> source) => {
      for (final entry in source.entries)
        entry.key.toString(): _deepCopy(entry.value),
    };

Object? _deepCopy(Object? value) => switch (value) {
      Map value => UnmodifiableMapView(_deepCopyMap(value)),
      Iterable value => List<Object?>.unmodifiable(value.map(_deepCopy)),
      _ => value,
    };

String _requiredString(Object? value, String label) {
  final normalized = value is String ? value.trim() : '';
  if (normalized.isEmpty) throw FormatException('$label is required.');
  return normalized;
}

String? _optionalString(Object? value) {
  final normalized = value is String ? value.trim() : '';
  return normalized.isEmpty ? null : normalized;
}

DateTime _requiredDate(Object? value, String label) {
  final parsed = DateTime.tryParse(value is String ? value : '');
  if (parsed == null) throw FormatException('$label is invalid.');
  return parsed;
}

int _positiveInt(Object? value, String label) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed < 1) {
    throw FormatException('$label must be positive.');
  }
  return parsed;
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, String label) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Unknown $label: $raw');
}

Map<String, Object?> _objectMap(Object? value) =>
    value is Map ? _deepCopyMap(value) : <String, Object?>{};
