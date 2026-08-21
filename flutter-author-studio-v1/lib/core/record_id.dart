/// Universal Records identity primitives.
///
/// This library is deliberately dependency-free: it imports no Flutter, no
/// persistence, no service and no Studio code. Every other AuthorOS layer may
/// depend on it, and it depends on nothing.
///
/// [RecordId] and [RelationshipId] do not introduce a second identity system.
/// They are typed, validated wrappers around the string identity that
/// `AuthorRecord.id` and `RecordLink.id` already persist, so a value can be
/// handed to the existing repositories unchanged via [value].
library;

/// A stable, immutable identity for a Universal Record.
///
/// Identity is never derived from a display title: two records may share a
/// title and still be different records.
class RecordId implements Comparable<RecordId> {
  const RecordId._(this.value);

  /// Wraps [value] after validating it, throwing [FormatException] when the
  /// value could not be persisted or compared safely.
  factory RecordId.parse(Object? value) =>
      RecordId._(_normalizeIdentity(value, 'Record id'));

  /// Wraps [value], returning `null` instead of throwing on invalid input.
  static RecordId? tryParse(Object? value) {
    try {
      return RecordId.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// Restores an id from its serialized form.
  factory RecordId.fromJson(Object? json) => RecordId.parse(json);

  /// The persisted string identity, byte-identical to `AuthorRecord.id`.
  final String value;

  /// The serialized form. Deterministic and stable across round-trips.
  String toJson() => value;

  @override
  int compareTo(RecordId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is RecordId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A stable, immutable identity for a relationship edge.
///
/// AuthorOS persists relationships as `RecordLink` rows; this wraps the same
/// `RecordLink.id` string.
class RelationshipId implements Comparable<RelationshipId> {
  const RelationshipId._(this.value);

  factory RelationshipId.parse(Object? value) =>
      RelationshipId._(_normalizeIdentity(value, 'Relationship id'));

  static RelationshipId? tryParse(Object? value) {
    try {
      return RelationshipId.parse(value);
    } on FormatException {
      return null;
    }
  }

  factory RelationshipId.fromJson(Object? json) => RelationshipId.parse(json);

  final String value;

  String toJson() => value;

  @override
  int compareTo(RelationshipId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is RelationshipId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Shared identity rules for records and relationships.
///
/// Control characters are rejected because identities are also written into
/// FTS index rows, NDJSON archives and audit summaries, where an embedded
/// newline would corrupt the surrounding record rather than fail loudly.
String _normalizeIdentity(Object? value, String label) {
  if (value is RecordId) return value.value;
  if (value is RelationshipId) return value.value;
  if (value is! String) {
    throw FormatException('$label must be a string.');
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw FormatException('$label is required.');
  }
  for (final unit in normalized.codeUnits) {
    if (unit < 0x20 || unit == 0x7f) {
      throw FormatException('$label must not contain control characters.');
    }
  }
  return normalized;
}
