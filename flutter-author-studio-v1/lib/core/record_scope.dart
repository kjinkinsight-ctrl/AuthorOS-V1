enum RecordScopeType {
  library,
  universe,
  series,
  project,
  book,
  branch,
  manuscript,
}

enum CanonStatus { canon, draft, proposed, deprecated, nonCanon, alternate }

class RecordScope {
  const RecordScope({
    required this.type,
    required this.id,
    required this.projectId,
    this.seriesId,
    this.bookId,
    this.branchId,
  });

  final RecordScopeType type;
  final String id;
  final String projectId;
  final String? seriesId;
  final String? bookId;
  final String? branchId;

  void validate() {
    if (id.trim().isEmpty || projectId.trim().isEmpty) {
      throw const FormatException('Scope id and project id are required.');
    }
    if (type == RecordScopeType.series && seriesId != id) {
      throw const FormatException('Series scope must identify its series.');
    }
    if (type == RecordScopeType.book && (seriesId == null || bookId != id)) {
      throw const FormatException('Book scope requires series and book ids.');
    }
    if (type == RecordScopeType.branch && branchId != id) {
      throw const FormatException('Branch scope must identify its branch.');
    }
  }

  Map<String, Object?> toJson() => {
        'type': type.name,
        'id': id,
        'projectId': projectId,
        'seriesId': seriesId,
        'bookId': bookId,
        'branchId': branchId,
      };

  factory RecordScope.fromJson(Map<String, dynamic> json) {
    final scope = RecordScope(
      type: _scopeType(json['type']),
      id: _requiredString(json['id'], 'Scope id'),
      projectId: _requiredString(json['projectId'], 'Project id'),
      seriesId: _optionalString(json['seriesId']),
      bookId: _optionalString(json['bookId']),
      branchId: _optionalString(json['branchId']),
    );
    scope.validate();
    return scope;
  }
}

RecordScopeType _scopeType(Object? raw) {
  for (final value in RecordScopeType.values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Unknown record scope: $raw');
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
