import 'connected_domain.dart';
import 'record_types.dart';

enum CodexCanonStatus {
  canon,
  draft,
  proposed,
  deprecated,
  nonCanon,
  alternate
}

enum CodexCollectionKind { manual, smart, pinned, savedView }

/// Where an entry lives, as the workspace presents it.
///
/// This is a two-value view over [RecordScopeType], not a second scope model:
/// `book` is anything the current project owns, `series` is anything it
/// inherits from a scope above it.
enum CodexScopeFacet { book, series }

CodexScopeFacet codexScopeFacetFor(RecordScopeType scopeType) =>
    switch (scopeType) {
      RecordScopeType.series ||
      RecordScopeType.universe ||
      RecordScopeType.library =>
        CodexScopeFacet.series,
      _ => CodexScopeFacet.book,
    };

String codexScopeFacetLabel(CodexScopeFacet facet) => switch (facet) {
      CodexScopeFacet.book => 'This book',
      CodexScopeFacet.series => 'Series',
    };

enum CodexKnowledgeStatus {
  confirmed,
  suspected,
  rumoured,
  falseInformation,
  unknown,
  secret,
  revealed,
}

enum CodexFieldVisibility { publicKnowledge, privateKnowledge, authorKnowledge }

class CodexStructuredField {
  const CodexStructuredField({
    required this.key,
    required this.label,
    required this.type,
    required this.value,
    required this.order,
    this.validation = const {},
    this.visibility = CodexFieldVisibility.authorKnowledge,
    this.templateId,
    this.custom = false,
  });

  final String key;
  final String label;
  final RecordFieldType type;
  final Object? value;
  final Map<String, Object?> validation;
  final CodexFieldVisibility visibility;
  final int order;
  final String? templateId;
  final bool custom;

  Map<String, Object?> toJson() => {
        'key': key,
        'label': label,
        'type': type.name,
        'value': value,
        'validation': validation,
        'visibility': visibility.name,
        'order': order,
        'templateId': templateId,
        'custom': custom,
      };

  factory CodexStructuredField.fromJson(Map<String, dynamic> json) =>
      CodexStructuredField(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        type: RecordFieldType.values.byName(
          json['type'] as String? ?? RecordFieldType.shortText.name,
        ),
        value: json['value'],
        validation: json['validation'] is Map
            ? (json['validation'] as Map)
                .map((key, value) => MapEntry(key.toString(), value))
            : const {},
        visibility: CodexFieldVisibility.values.byName(
          json['visibility'] as String? ??
              CodexFieldVisibility.authorKnowledge.name,
        ),
        order: (json['order'] as num?)?.toInt() ?? 0,
        templateId: _string(json['templateId']),
        custom: json['custom'] as bool? ?? false,
      );
}

class CodexSourceReference {
  const CodexSourceReference({
    required this.recordId,
    required this.kind,
    this.id = '',
    this.label = '',
    this.location = '',
    this.notes = '',
  });

  final String id;
  final String recordId;
  final String kind;
  final String label;
  final String location;
  final String notes;

  String get stableId => id.isNotEmpty
      ? id
      : recordId.isNotEmpty
          ? recordId
          : '$kind:$label:$location';

  String get displayLabel => label.isNotEmpty
      ? label
      : recordId.isNotEmpty
          ? recordId
          : kind;

  CodexSourceReference copyWith({
    String? id,
    String? recordId,
    String? kind,
    String? label,
    String? location,
    String? notes,
  }) =>
      CodexSourceReference(
        id: id ?? this.id,
        recordId: recordId ?? this.recordId,
        kind: kind ?? this.kind,
        label: label ?? this.label,
        location: location ?? this.location,
        notes: notes ?? this.notes,
      );

  Map<String, Object?> toJson() => {
        'id': stableId,
        'recordId': recordId,
        'kind': kind,
        'label': label,
        'location': location,
        'notes': notes,
      };

  factory CodexSourceReference.fromJson(Map<String, dynamic> json) =>
      CodexSourceReference(
        id: json['id'] as String? ?? '',
        recordId: json['recordId'] as String? ?? '',
        kind: json['kind'] as String? ?? 'reference',
        label: json['label'] as String? ?? '',
        location: json['location'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );

  /// Reads a persisted `sourceReferences` list value.
  ///
  /// Values written by earlier releases or by other Studios are plain strings.
  /// They are preserved as free-text references instead of being dropped so
  /// round-tripping an entry through the workspace never loses data.
  static List<CodexSourceReference> listFrom(Object? value) {
    if (value is! List) return const [];
    return value.map((item) {
      if (item is Map) {
        return CodexSourceReference.fromJson(
          item.map((key, entry) => MapEntry(key.toString(), entry)),
        );
      }
      return CodexSourceReference(
        recordId: '',
        kind: 'reference',
        label: item.toString(),
      );
    }).toList();
  }
}

/// The stored `knowledgeStatus` option for [status].
///
/// Values must stay inside the template's `singleChoice` option list or record
/// validation rejects them.
String codexKnowledgeStatusValue(CodexKnowledgeStatus status) =>
    switch (status) {
      CodexKnowledgeStatus.confirmed => 'Confirmed',
      CodexKnowledgeStatus.suspected => 'Suspected',
      CodexKnowledgeStatus.rumoured => 'Rumoured',
      CodexKnowledgeStatus.falseInformation => 'False',
      CodexKnowledgeStatus.unknown => 'Unknown',
      CodexKnowledgeStatus.secret => 'Secret',
      CodexKnowledgeStatus.revealed => 'Revealed',
    };

String codexKnowledgeStatusLabel(CodexKnowledgeStatus status) =>
    status == CodexKnowledgeStatus.falseInformation
        ? 'False information'
        : codexKnowledgeStatusValue(status);

String codexCanonStatusLabel(CodexCanonStatus status) => switch (status) {
      CodexCanonStatus.canon => 'Canon',
      CodexCanonStatus.draft => 'Draft',
      CodexCanonStatus.proposed => 'Proposed',
      CodexCanonStatus.deprecated => 'Deprecated',
      CodexCanonStatus.nonCanon => 'Non-Canon',
      CodexCanonStatus.alternate => 'Alternate',
    };

String codexVisibilityLabel(CodexFieldVisibility visibility) =>
    switch (visibility) {
      CodexFieldVisibility.publicKnowledge => 'Public knowledge',
      CodexFieldVisibility.privateKnowledge => 'Private knowledge',
      CodexFieldVisibility.authorKnowledge => 'Author only',
    };

const codexSourceKinds = <String>[
  'manuscript',
  'chapter',
  'scene',
  'research',
  'external',
  'reference',
  'author-note',
];

class CodexFields {
  const CodexFields._();

  static const prefix = '_codex.';
  static const summary = '${prefix}summary';
  static const content = '${prefix}content';
  static const templateId = '${prefix}templateId';
  static const categoryId = '${prefix}categoryId';
  static const projectId = '${prefix}projectId';
  static const seriesId = '${prefix}seriesId';
  static const bookId = '${prefix}bookId';
  static const canonStatus = '${prefix}canonStatus';
  static const branchId = '${prefix}branchId';
  static const metadata = '${prefix}metadata';

  /// Template-owned field that stores source and reference entries.
  static const sources = 'sourceReferences';

  /// Template-owned field that stores the author-facing knowledge status.
  static const knowledgeStatus = 'knowledgeStatus';

  /// Template-owned field that stores alternate names for an entry.
  static const aliases = 'aliases';

  /// Key inside [metadata] holding per-field knowledge visibility.
  static const visibilityKey = 'fieldVisibility';

  /// Key inside [metadata] holding author-added custom field labels.
  static const customFieldsKey = 'customFields';
}

class CodexInfrastructureTypes {
  const CodexInfrastructureTypes._();

  static const category = 'codexCategory';
  static const tag = 'codexTag';
  static const collection = 'codexCollection';

  static const all = {category, tag, collection};
}

class CodexEntryDraft {
  const CodexEntryDraft({
    required this.title,
    required this.templateId,
    required this.categoryId,
    this.id,
    this.summary = '',
    this.content = '',
    this.structuredFields = const {},
    this.tagIds = const [],
    this.seriesId,
    this.bookId,
    this.branchId,
    this.canonStatus = CodexCanonStatus.draft,
    this.scopeType = RecordScopeType.project,
    this.ownerScopeId,
    this.metadata = const {},
  });

  final String? id;
  final String title;
  final String templateId;
  final String categoryId;
  final String summary;
  final String content;
  final Map<String, Object?> structuredFields;
  final List<String> tagIds;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final CodexCanonStatus canonStatus;
  final RecordScopeType scopeType;
  final String? ownerScopeId;
  final Map<String, Object?> metadata;
}

class CodexEntry {
  const CodexEntry(this.record);

  final AuthorRecord record;

  String get id => record.id;
  String get title => record.title;
  String get recordType =>
      _string(record.fields[CodexFields.templateId]) ??
      _string(record.fields['_world.templateId']) ??
      record.typeId;
  String get templateId => recordType;
  String get categoryId =>
      _string(record.fields[CodexFields.categoryId]) ??
      _string(record.fields['_world.categoryId']) ??
      _defaultCategory(recordType);
  String get summary =>
      _string(record.fields[CodexFields.summary]) ??
      _string(record.fields['summary']) ??
      _string(record.fields['identity.description']) ??
      '';
  String get content => _string(record.fields[CodexFields.content]) ?? '';
  String get projectId =>
      _string(record.fields[CodexFields.projectId]) ?? record.scopeId;
  // The column is the authority and the field is a mirror of it, so the column
  // is read first. Entries written before scopes were instantiated only have
  // the field, which is why the fallback stays.
  String? get seriesId =>
      _string(record.seriesId) ?? _string(record.fields[CodexFields.seriesId]);
  String? get bookId =>
      _string(record.bookId) ?? _string(record.fields[CodexFields.bookId]);

  RecordScopeType get scopeType => record.scopeType;

  CodexScopeFacet get scopeFacet => codexScopeFacetFor(record.scopeType);

  /// Whether this entry is shared canon rather than this book's own.
  bool get isShared => scopeFacet == CodexScopeFacet.series;
  String? get branchId => _string(record.fields[CodexFields.branchId]);
  List<String> get tagIds => record.tags;
  List<String> get aliases => _stringList(record.fields['aliases']);
  AuthorRecordStatus get status => record.status;
  DateTime get createdAt => record.createdAt;
  DateTime get updatedAt => record.updatedAt;
  CodexCanonStatus get canonStatus {
    final raw = _string(record.fields[CodexFields.canonStatus]) ??
        _string(record.fields['_world.canonStatus']);
    return CodexCanonStatus.values.firstWhere(
      (status) => status.name == raw,
      orElse: () => CodexCanonStatus.draft,
    );
  }

  Map<String, Object?> get structuredFields => {
        for (final field in record.fields.entries)
          if (!field.key.startsWith(CodexFields.prefix) &&
              !field.key.startsWith('_world.') &&
              !field.key.startsWith('_character.'))
            field.key: field.value,
      };

  Map<String, Object?> get metadata {
    final value = record.fields[CodexFields.metadata];
    return value is Map
        ? value.map((key, item) => MapEntry(key.toString(), item))
        : const {};
  }

  CodexKnowledgeStatus get knowledgeStatus {
    final normalized = _string(record.fields['knowledgeStatus'])
        ?.replaceAll(' ', '')
        .toLowerCase();
    return switch (normalized) {
      'confirmed' => CodexKnowledgeStatus.confirmed,
      'suspected' => CodexKnowledgeStatus.suspected,
      'rumoured' => CodexKnowledgeStatus.rumoured,
      'false' || 'falseinformation' => CodexKnowledgeStatus.falseInformation,
      'secret' => CodexKnowledgeStatus.secret,
      'revealed' => CodexKnowledgeStatus.revealed,
      _ => CodexKnowledgeStatus.unknown,
    };
  }

  bool get isArchived => status == AuthorRecordStatus.archived;
  bool get isDeleted => status == AuthorRecordStatus.deleted;

  List<CodexSourceReference> get sources =>
      CodexSourceReference.listFrom(record.fields[CodexFields.sources]);

  /// Author-declared visibility per field, keyed by field id.
  ///
  /// Fields with no declared visibility fall back to author knowledge so that
  /// nothing is revealed to a reader-facing export by accident.
  Map<String, CodexFieldVisibility> get fieldVisibility {
    final raw = metadata[CodexFields.visibilityKey];
    if (raw is! Map) return const {};
    final parsed = <String, CodexFieldVisibility>{};
    for (final entry in raw.entries) {
      final match = CodexFieldVisibility.values
          .where((value) => value.name == entry.value)
          .firstOrNull;
      if (match != null) parsed[entry.key.toString()] = match;
    }
    return parsed;
  }

  CodexFieldVisibility visibilityFor(String fieldId) =>
      fieldVisibility[fieldId] ?? CodexFieldVisibility.authorKnowledge;
}

/// A reusable, persisted filter over the Codex entry list.
class CodexSavedView {
  const CodexSavedView({
    required this.id,
    required this.name,
    required this.filter,
  });

  final String id;
  final String name;
  final CodexEntryFilter filter;

  factory CodexSavedView.fromCollection(CodexCollection collection) =>
      CodexSavedView(
        id: collection.id,
        name: collection.name,
        filter: CodexEntryFilter.fromJson(collection.filter),
      );
}

enum CodexEditorMode { simple, deep }

enum CodexEntrySort { recentlyUpdated, title, canonStatus }

/// Declarative filter applied to the workspace entry list.
///
/// Everything here is serialisable so a filter can be stored verbatim inside a
/// `codexCollection` universal record and restored as a saved view.
class CodexEntryFilter {
  const CodexEntryFilter({
    this.query = '',
    this.categoryIds = const {},
    this.templateIds = const {},
    this.tagIds = const {},
    this.canonStatuses = const {},
    this.knowledgeStatuses = const {},
    this.scopes = const {},
    this.includeArchived = false,
    this.onlyPinned = false,
    this.onlyInvalid = false,
    this.sort = CodexEntrySort.recentlyUpdated,
  });

  final String query;
  final Set<String> categoryIds;
  final Set<String> templateIds;
  final Set<String> tagIds;
  final Set<CodexCanonStatus> canonStatuses;
  final Set<CodexKnowledgeStatus> knowledgeStatuses;
  final Set<CodexScopeFacet> scopes;
  final bool includeArchived;
  final bool onlyPinned;
  final bool onlyInvalid;
  final CodexEntrySort sort;

  static const empty = CodexEntryFilter();

  bool get isEmpty =>
      query.trim().isEmpty &&
      categoryIds.isEmpty &&
      templateIds.isEmpty &&
      tagIds.isEmpty &&
      canonStatuses.isEmpty &&
      knowledgeStatuses.isEmpty &&
      scopes.isEmpty &&
      !includeArchived &&
      !onlyPinned &&
      !onlyInvalid;

  int get activeFacetCount =>
      (query.trim().isEmpty ? 0 : 1) +
      categoryIds.length +
      templateIds.length +
      tagIds.length +
      canonStatuses.length +
      knowledgeStatuses.length +
      scopes.length +
      (includeArchived ? 1 : 0) +
      (onlyPinned ? 1 : 0) +
      (onlyInvalid ? 1 : 0);

  CodexEntryFilter copyWith({
    String? query,
    Set<String>? categoryIds,
    Set<String>? templateIds,
    Set<String>? tagIds,
    Set<CodexCanonStatus>? canonStatuses,
    Set<CodexKnowledgeStatus>? knowledgeStatuses,
    Set<CodexScopeFacet>? scopes,
    bool? includeArchived,
    bool? onlyPinned,
    bool? onlyInvalid,
    CodexEntrySort? sort,
  }) =>
      CodexEntryFilter(
        query: query ?? this.query,
        categoryIds: categoryIds ?? this.categoryIds,
        templateIds: templateIds ?? this.templateIds,
        tagIds: tagIds ?? this.tagIds,
        canonStatuses: canonStatuses ?? this.canonStatuses,
        knowledgeStatuses: knowledgeStatuses ?? this.knowledgeStatuses,
        scopes: scopes ?? this.scopes,
        includeArchived: includeArchived ?? this.includeArchived,
        onlyPinned: onlyPinned ?? this.onlyPinned,
        onlyInvalid: onlyInvalid ?? this.onlyInvalid,
        sort: sort ?? this.sort,
      );

  CodexEntryFilter toggleCategory(String id) =>
      copyWith(categoryIds: _toggle(categoryIds, id));
  CodexEntryFilter toggleTemplate(String id) =>
      copyWith(templateIds: _toggle(templateIds, id));
  CodexEntryFilter toggleTag(String id) => copyWith(tagIds: _toggle(tagIds, id));
  CodexEntryFilter toggleCanonStatus(CodexCanonStatus status) =>
      copyWith(canonStatuses: _toggle(canonStatuses, status));
  CodexEntryFilter toggleKnowledgeStatus(CodexKnowledgeStatus status) =>
      copyWith(knowledgeStatuses: _toggle(knowledgeStatuses, status));
  CodexEntryFilter toggleScope(CodexScopeFacet facet) =>
      copyWith(scopes: _toggle(scopes, facet));

  Map<String, Object?> toJson() => {
        'query': query,
        'categoryIds': categoryIds.toList()..sort(),
        'templateIds': templateIds.toList()..sort(),
        'tagIds': tagIds.toList()..sort(),
        'canonStatuses': canonStatuses.map((value) => value.name).toList()
          ..sort(),
        'knowledgeStatuses': knowledgeStatuses.map((value) => value.name).toList()
          ..sort(),
        'scopes': scopes.map((value) => value.name).toList()..sort(),
        'includeArchived': includeArchived,
        'onlyPinned': onlyPinned,
        'onlyInvalid': onlyInvalid,
        'sort': sort.name,
      };

  factory CodexEntryFilter.fromJson(Map<String, Object?> json) =>
      CodexEntryFilter(
        query: json['query'] as String? ?? '',
        categoryIds: _stringList(json['categoryIds']).toSet(),
        templateIds: _stringList(json['templateIds']).toSet(),
        tagIds: _stringList(json['tagIds']).toSet(),
        canonStatuses: _enumSet(
          CodexCanonStatus.values,
          json['canonStatuses'],
        ),
        knowledgeStatuses: _enumSet(
          CodexKnowledgeStatus.values,
          json['knowledgeStatuses'],
        ),
        scopes: _enumSet(CodexScopeFacet.values, json['scopes']),
        includeArchived: json['includeArchived'] as bool? ?? false,
        onlyPinned: json['onlyPinned'] as bool? ?? false,
        onlyInvalid: json['onlyInvalid'] as bool? ?? false,
        sort: CodexEntrySort.values
                .where((value) => value.name == json['sort'])
                .firstOrNull ??
            CodexEntrySort.recentlyUpdated,
      );
}

Set<T> _toggle<T>(Set<T> source, T value) {
  final next = source.toSet();
  next.contains(value) ? next.remove(value) : next.add(value);
  return next;
}

Set<T> _enumSet<T extends Enum>(List<T> values, Object? raw) => {
      for (final name in _stringList(raw))
        for (final value in values)
          if (value.name == name) value,
    };

class CodexCategory {
  const CodexCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.archived = false,
    this.order = 0,
  });

  final String id;
  final String name;
  final String? parentId;
  final bool archived;
  final int order;
}

class CodexTag {
  const CodexTag({
    required this.id,
    required this.name,
    required this.createdAt,
    this.description = '',
    this.group = '',
    this.color = '',
  });

  final String id;
  final String name;
  final String description;
  final String group;
  final String color;
  final DateTime createdAt;
}

class CodexCollection {
  const CodexCollection({
    required this.id,
    required this.name,
    required this.kind,
    this.recordIds = const [],
    this.filter = const {},
  });

  final String id;
  final String name;
  final CodexCollectionKind kind;
  final List<String> recordIds;
  final Map<String, Object?> filter;
}

const officialCodexCategories = <CodexCategory>[
  CodexCategory(id: 'world', name: 'World', order: 0),
  CodexCategory(id: 'characters', name: 'Characters', order: 1),
  CodexCategory(id: 'locations', name: 'Locations', order: 2),
  CodexCategory(id: 'factions', name: 'Factions', order: 3),
  CodexCategory(id: 'history', name: 'History', order: 4),
  CodexCategory(id: 'magic', name: 'Magic', order: 5),
  CodexCategory(id: 'technology', name: 'Technology', order: 6),
  CodexCategory(id: 'culture', name: 'Culture', order: 7),
  CodexCategory(id: 'religion', name: 'Religion', order: 8),
  CodexCategory(id: 'creatures', name: 'Creatures', order: 9),
  CodexCategory(id: 'items', name: 'Items', order: 10),
  CodexCategory(id: 'manuscript', name: 'Manuscript', order: 11),
  CodexCategory(id: 'plot', name: 'Plot', order: 12),
  CodexCategory(id: 'lore', name: 'Lore', order: 13),
  CodexCategory(id: 'research', name: 'Research', order: 14),
  CodexCategory(id: 'reference', name: 'Reference', order: 15),
  CodexCategory(id: 'custom', name: 'Custom', order: 16),
];

String? _string(Object? value) {
  final normalized = value is String ? value.trim() : '';
  return normalized.isEmpty ? null : normalized;
}

List<String> _stringList(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];

String _defaultCategory(String typeId) => switch (typeId) {
      'character' => 'characters',
      'location' || 'place' => 'locations',
      'faction' || 'organisation' => 'factions',
      'historical-event' || 'era' => 'history',
      'magic-system' || 'magic-rule' => 'magic',
      'technology' => 'technology',
      'culture' || 'language' || 'currency' => 'culture',
      'religion' => 'religion',
      'species' || 'creature' => 'creatures',
      'item' || 'artefact' || 'object' => 'items',
      'secret' ||
      'mystery' ||
      'clue' ||
      'plot-thread' ||
      'theme' ||
      'symbol' =>
        'plot',
      'research-entry' || 'research' => 'research',
      'reference' || 'glossary-term' || 'glossary' => 'reference',
      'general-lore' || 'lore' => 'lore',
      _ => 'world',
    };
