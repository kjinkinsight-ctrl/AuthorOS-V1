import 'connected_domain.dart';

enum BranchKind {
  whatIf,
  alternateTimeline,
  alternateEnding,
  alternateUniverse,
  draft,
}

enum BranchStatus { active, archived }

enum BranchRecordState { inherited, overridden, created, hidden }

enum BranchLinkState { added, hidden }

class StoryBranch {
  const StoryBranch({
    required this.id,
    required this.projectId,
    required this.name,
    required this.createdAt,
    this.description = '',
    this.kind = BranchKind.draft,
    this.parentBranchId,
    this.status = BranchStatus.active,
  });

  final String id;
  final String projectId;
  final String name;
  final String description;
  final BranchKind kind;
  final String? parentBranchId;
  final DateTime createdAt;
  final BranchStatus status;

  Map<String, Object?> toJson() => {
        'id': id,
        'projectId': projectId,
        'name': name,
        'description': description,
        'kind': kind.name,
        'parentBranchId': parentBranchId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'status': status.name,
      };

  factory StoryBranch.fromJson(Map<String, dynamic> json) => StoryBranch(
        id: _requiredString(json['id'], 'Branch id'),
        projectId: _requiredString(json['projectId'], 'Branch project id'),
        name: _requiredString(json['name'], 'Branch name'),
        description: json['description'] as String? ?? '',
        kind: _enumValue(
          BranchKind.values,
          json['kind'] ?? BranchKind.draft.name,
          'branch kind',
        ),
        parentBranchId: _optionalString(json['parentBranchId']),
        createdAt: _requiredDate(json['createdAt'], 'Branch createdAt'),
        status: _enumValue(
          BranchStatus.values,
          json['status'] ?? BranchStatus.active.name,
          'branch status',
        ),
      );
}

class BranchRecordOverlay {
  const BranchRecordOverlay({
    required this.branchId,
    required this.recordId,
    required this.state,
    required this.updatedAt,
    this.title,
    this.fields = const {},
    this.removedFieldIds = const [],
    this.tags,
    this.canonStatus,
    this.createdRecord,
  });

  final String branchId;
  final String recordId;
  final BranchRecordState state;
  final DateTime updatedAt;
  final String? title;
  final Map<String, Object?> fields;
  final List<String> removedFieldIds;
  final List<String>? tags;
  final CanonStatus? canonStatus;
  final AuthorRecord? createdRecord;

  Map<String, Object?> toJson() => {
        'branchId': branchId,
        'recordId': recordId,
        'state': state.name,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'title': title,
        'fields': fields,
        'removedFieldIds': removedFieldIds,
        'tags': tags,
        'canonStatus': canonStatus?.name,
        'createdRecord': createdRecord?.toJson(),
      };

  factory BranchRecordOverlay.fromJson(Map<String, dynamic> json) =>
      BranchRecordOverlay(
        branchId: _requiredString(json['branchId'], 'Overlay branch id'),
        recordId: _requiredString(json['recordId'], 'Overlay record id'),
        state: _enumValue(
          BranchRecordState.values,
          json['state'],
          'branch record state',
        ),
        updatedAt: _requiredDate(json['updatedAt'], 'Overlay updatedAt'),
        title: _optionalString(json['title']),
        fields: _objectMap(json['fields']),
        removedFieldIds: _stringList(json['removedFieldIds']),
        tags: json['tags'] == null ? null : _stringList(json['tags']),
        canonStatus: json['canonStatus'] == null
            ? null
            : _enumValue(
                CanonStatus.values,
                json['canonStatus'],
                'canon status',
              ),
        createdRecord: json['createdRecord'] is Map
            ? AuthorRecord.fromJson(
                Map<String, dynamic>.from(json['createdRecord'] as Map),
              )
            : null,
      );
}

class BranchLinkOverlay {
  const BranchLinkOverlay({
    required this.branchId,
    required this.linkId,
    required this.state,
    required this.updatedAt,
    this.link,
  });

  final String branchId;
  final String linkId;
  final BranchLinkState state;
  final DateTime updatedAt;
  final RecordLink? link;

  Map<String, Object?> toJson() => {
        'branchId': branchId,
        'linkId': linkId,
        'state': state.name,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'link': link?.toJson(),
      };

  factory BranchLinkOverlay.fromJson(Map<String, dynamic> json) =>
      BranchLinkOverlay(
        branchId: _requiredString(json['branchId'], 'Link overlay branch id'),
        linkId: _requiredString(json['linkId'], 'Link overlay link id'),
        state: _enumValue(
          BranchLinkState.values,
          json['state'],
          'branch link state',
        ),
        updatedAt: _requiredDate(json['updatedAt'], 'Link overlay updatedAt'),
        link: json['link'] is Map
            ? RecordLink.fromJson(
                Map<String, dynamic>.from(json['link'] as Map),
              )
            : null,
      );
}

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

T _enumValue<T extends Enum>(List<T> values, Object? raw, String label) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Unknown $label: $raw');
}

Map<String, Object?> _objectMap(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, Object?>{};

List<String> _stringList(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : [];
