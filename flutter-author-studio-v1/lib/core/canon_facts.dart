import 'connected_domain.dart';

/// The canon status of a single fact, as the directive asks for it.
///
/// Deliberately not [CanonStatus]. That enum is persisted in a database column
/// and an FTS column and describes a whole *record*; this describes one
/// *field*, has seven values rather than six, and two of its values are never
/// stored at all. Conflating the two would corrupt existing canon filters.
enum CanonFactStatus {
  canon,
  proposed,
  draft,
  alternate,

  /// Superseded, kept for reference. Stored as [CanonStatus.deprecated].
  retired,

  /// **Derived, never stored.** A fact is contradicted while something
  /// disagrees with it — the moment the author resolves the disagreement it
  /// stops being contradicted, so storing it would go stale immediately.
  contradicted,

  /// **Derived, never stored.** No status has been declared for this fact.
  unknown,
}

/// Where per-fact canon lives on a record.
///
/// Namespaced the way `_codex.` and `_world.` already are. Only [fieldStatus]
/// is persisted; confidence and contradiction are computed on read.
class CanonFields {
  const CanonFields._();

  static const prefix = '_canon.';

  /// `{fieldId: CanonFactStatus.name}` — the author's declared status per field.
  static const fieldStatus = '${prefix}fieldStatus';

  /// `{fieldId: sourceReferenceId}` — what a fact is sourced from.
  static const fieldSource = '${prefix}fieldSource';

  /// The status of one field on [record].
  ///
  /// A field with no declared status inherits the record's own canon status, so
  /// an author who never touches per-fact canon still gets a sensible answer.
  static CanonFactStatus statusFor(AuthorRecord record, String fieldId) {
    final declared = _statusMap(record)[fieldId];
    if (declared != null) return declared;
    return fromRecordStatus(record.canonStatus);
  }

  /// Every per-fact status declared on [record].
  static Map<String, CanonFactStatus> declaredStatuses(AuthorRecord record) =>
      _statusMap(record);

  /// Sets the status of one field, returning the fields map to store.
  static Map<String, Object?> withFieldStatus(
    AuthorRecord record,
    String fieldId,
    CanonFactStatus status,
  ) {
    if (status == CanonFactStatus.contradicted ||
        status == CanonFactStatus.unknown) {
      throw ArgumentError(
        '${status.name} is derived and cannot be stored. Resolve the '
        'contradiction, or declare a real status.',
      );
    }
    final declared = {
      for (final entry in _statusMap(record).entries) entry.key: entry.value.name,
      fieldId: status.name,
    };
    return {...record.fields, fieldStatus: declared};
  }

  /// The source reference recorded for one field, if any.
  static String? sourceFor(AuthorRecord record, String fieldId) {
    final raw = record.fields[fieldSource];
    if (raw is! Map) return null;
    final value = raw[fieldId];
    final normalized = value is String ? value.trim() : '';
    return normalized.isEmpty ? null : normalized;
  }

  /// How a record's canon status reads as a fact status.
  static CanonFactStatus fromRecordStatus(CanonStatus status) =>
      switch (status) {
        CanonStatus.canon => CanonFactStatus.canon,
        CanonStatus.proposed => CanonFactStatus.proposed,
        CanonStatus.draft => CanonFactStatus.draft,
        CanonStatus.alternate => CanonFactStatus.alternate,
        CanonStatus.deprecated => CanonFactStatus.retired,
        CanonStatus.nonCanon => CanonFactStatus.alternate,
      };

  /// How a fact status is persisted.
  ///
  /// Retired maps onto the existing `deprecated`; the two derived states have
  /// no stored form, which is the point of them.
  static CanonStatus toRecordStatus(CanonFactStatus status) => switch (status) {
        CanonFactStatus.canon => CanonStatus.canon,
        CanonFactStatus.proposed => CanonStatus.proposed,
        CanonFactStatus.draft => CanonStatus.draft,
        CanonFactStatus.alternate => CanonStatus.alternate,
        CanonFactStatus.retired => CanonStatus.deprecated,
        CanonFactStatus.contradicted ||
        CanonFactStatus.unknown =>
          throw ArgumentError('${status.name} is derived and has no stored '
              'form.'),
      };

  static Map<String, CanonFactStatus> _statusMap(AuthorRecord record) {
    final raw = record.fields[fieldStatus];
    if (raw is! Map) return const {};
    final parsed = <String, CanonFactStatus>{};
    for (final entry in raw.entries) {
      final match = CanonFactStatus.values
          .where((value) => value.name == entry.value)
          .firstOrNull;
      if (match != null) parsed[entry.key.toString()] = match;
    }
    return parsed;
  }
}

/// One fact, and everything that bears on how much to trust it.
class CanonFact {
  const CanonFact({
    required this.recordId,
    required this.fieldId,
    required this.value,
    required this.status,
    required this.sourceCount,
    required this.agreeingStateCount,
    required this.contradictionCount,
    this.bookId,
  });

  final String recordId;
  final String fieldId;
  final Object? value;
  final CanonFactStatus status;

  /// Source references plus incoming `documents` links.
  final int sourceCount;

  /// Book states asserting the same value.
  final int agreeingStateCount;

  /// Unresolved contradictions naming this fact.
  final int contradictionCount;

  final String? bookId;

  bool get isContradicted => contradictionCount > 0;

  /// The status as it should be shown, which is not always the stored one.
  CanonFactStatus get effectiveStatus =>
      isContradicted ? CanonFactStatus.contradicted : status;
}

/// How far to trust [fact], from 0 to 1.
///
/// A pure function of typed inputs — a declared status and three counts. There
/// is no model here and no estimate: the same fact always produces the same
/// number, and a test asserts the exact arithmetic. That matters because a
/// confidence an author cannot predict is a confidence they cannot use.
double canonConfidence(CanonFact fact) {
  if (fact.status == CanonFactStatus.retired) return 0.0;
  if (fact.isContradicted) return 0.25;
  return switch (fact.status) {
    CanonFactStatus.canon =>
      fact.sourceCount == 0 && fact.agreeingStateCount == 0 ? 0.8 : 1.0,
    CanonFactStatus.proposed => 0.6,
    CanonFactStatus.draft => 0.4,
    CanonFactStatus.alternate => 0.3,
    CanonFactStatus.unknown => 0.1,
    CanonFactStatus.retired => 0.0,
    CanonFactStatus.contradicted => 0.25,
  };
}

String canonFactStatusLabel(CanonFactStatus status) => switch (status) {
      CanonFactStatus.canon => 'Canon',
      CanonFactStatus.proposed => 'Proposed',
      CanonFactStatus.draft => 'Draft',
      CanonFactStatus.alternate => 'Alternate',
      CanonFactStatus.retired => 'Retired',
      CanonFactStatus.contradicted => 'Contradicted',
      CanonFactStatus.unknown => 'Unknown',
    };
