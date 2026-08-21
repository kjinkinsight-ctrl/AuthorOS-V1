/// Research Studio domain vocabulary.
///
/// Plain Dart. Must not import Flutter.
///
/// Research Studio owns no record model of its own: a research item **is** a
/// Universal Record read through [CodexEntry], exactly as World Studio reads
/// world records through [AuthorRecord]. This library only adds the vocabulary
/// the Studio needs on top of that shared model — which record types it owns,
/// how a research item is filtered and sorted, and the derived read-models its
/// dashboard renders. Nothing here is persisted.
library;

import 'story_codex_domain.dart';

/// The Universal Record types Research Studio is responsible for.
///
/// Every id here already exists in `BuiltInRecordTypes`; Research Studio adds
/// no record type and no field. The set is split so the create dialog can offer
/// real templates while reads still accept the legacy selectable aliases
/// (`research`, `glossary`) that older entries may carry.
class ResearchRecordTypes {
  const ResearchRecordTypes._();

  /// The canonical research record type.
  static const entryTypeId = 'research-entry';

  /// Types offered when creating research, in display order.
  static const templateIds = <String>[
    entryTypeId,
    'reference',
    'document',
    'glossary-term',
    'author-note',
  ];

  /// Selectable aliases that resolve to a template in [templateIds].
  static const aliasIds = <String>{'research', 'glossary'};

  /// Every type id Research Studio reads.
  static const typeIds = <String>{...templateIds, ...aliasIds};

  /// The Codex categories research records are filed under.
  static const categoryIds = <String>{'research', 'reference'};

  /// True when [typeId] belongs to Research Studio.
  static bool owns(String typeId) => typeIds.contains(typeId);

  /// The template an alias resolves to, or [typeId] when it is already one.
  static String resolveTemplate(String typeId) => switch (typeId) {
        'research' => entryTypeId,
        'glossary' => 'glossary-term',
        _ => typeId,
      };

  static String label(String typeId) => switch (typeId) {
        entryTypeId || 'research' => 'Research Entry',
        'reference' => 'Reference',
        'document' => 'Document',
        'glossary-term' || 'glossary' => 'Glossary Term',
        'author-note' => 'Author Note',
        _ => typeId,
      };
}

/// Ordering applied to the research library list.
enum ResearchSort { recentlyUpdated, title, reliability }

String researchSortLabel(ResearchSort sort) => switch (sort) {
      ResearchSort.recentlyUpdated => 'Recently updated',
      ResearchSort.title => 'Title',
      ResearchSort.reliability => 'Reliability',
    };

/// How settled a research item is, read from its knowledge status.
///
/// The values are the existing `knowledgeStatus` template options; Research
/// Studio only groups them into an ordering a researcher recognises.
int researchReliabilityRank(CodexKnowledgeStatus status) => switch (status) {
      CodexKnowledgeStatus.confirmed => 0,
      CodexKnowledgeStatus.revealed => 1,
      CodexKnowledgeStatus.suspected => 2,
      CodexKnowledgeStatus.rumoured => 3,
      CodexKnowledgeStatus.secret => 4,
      CodexKnowledgeStatus.unknown => 5,
      CodexKnowledgeStatus.falseInformation => 6,
    };

/// True when [entry] is settled: verified knowledge backed by a source.
///
/// Both halves come from fields the record already carries — `knowledgeStatus`
/// and `sourceReferences` — so "unresolved" is a reading of the stored record,
/// never a flag Research Studio writes.
bool researchIsResolved(CodexEntry entry) =>
    (entry.knowledgeStatus == CodexKnowledgeStatus.confirmed ||
        entry.knowledgeStatus == CodexKnowledgeStatus.revealed) &&
    entry.sources.isNotEmpty;

/// Why [entry] is still unresolved, or an empty string when it is settled.
String researchUnresolvedReason(CodexEntry entry) {
  if (researchIsResolved(entry)) return '';
  final needsVerification =
      entry.knowledgeStatus != CodexKnowledgeStatus.confirmed &&
          entry.knowledgeStatus != CodexKnowledgeStatus.revealed;
  if (needsVerification && entry.sources.isEmpty) {
    return 'Unverified and unsourced';
  }
  return needsVerification ? 'Needs verification' : 'Needs a source';
}

/// Declarative filter over the research library.
///
/// Everything is serialisable, and every facet except [onlyUnresolved] maps
/// straight onto [CodexEntryFilter] so filtering runs through the Codex service
/// rather than a second filter engine. [onlyUnresolved] is derived from stored
/// fields by [researchIsResolved] after that query returns.
class ResearchFilter {
  const ResearchFilter({
    this.query = '',
    this.typeIds = const {},
    this.categoryIds = const {},
    this.tagIds = const {},
    this.canonStatuses = const {},
    this.knowledgeStatuses = const {},
    this.includeArchived = false,
    this.onlyUnresolved = false,
    this.onlyConnected = false,
    this.sort = ResearchSort.recentlyUpdated,
  });

  final String query;
  final Set<String> typeIds;
  final Set<String> categoryIds;
  final Set<String> tagIds;
  final Set<CodexCanonStatus> canonStatuses;
  final Set<CodexKnowledgeStatus> knowledgeStatuses;
  final bool includeArchived;

  /// Keeps only items [researchIsResolved] rejects.
  final bool onlyUnresolved;

  /// Keeps only items linked to another record in the project.
  final bool onlyConnected;

  final ResearchSort sort;

  static const empty = ResearchFilter();

  bool get isEmpty =>
      query.trim().isEmpty &&
      typeIds.isEmpty &&
      categoryIds.isEmpty &&
      tagIds.isEmpty &&
      canonStatuses.isEmpty &&
      knowledgeStatuses.isEmpty &&
      !includeArchived &&
      !onlyUnresolved &&
      !onlyConnected &&
      sort == ResearchSort.recentlyUpdated;

  int get activeFacetCount =>
      (query.trim().isEmpty ? 0 : 1) +
      typeIds.length +
      categoryIds.length +
      tagIds.length +
      canonStatuses.length +
      knowledgeStatuses.length +
      (includeArchived ? 1 : 0) +
      (onlyUnresolved ? 1 : 0) +
      (onlyConnected ? 1 : 0);

  ResearchFilter copyWith({
    String? query,
    Set<String>? typeIds,
    Set<String>? categoryIds,
    Set<String>? tagIds,
    Set<CodexCanonStatus>? canonStatuses,
    Set<CodexKnowledgeStatus>? knowledgeStatuses,
    bool? includeArchived,
    bool? onlyUnresolved,
    bool? onlyConnected,
    ResearchSort? sort,
  }) =>
      ResearchFilter(
        query: query ?? this.query,
        typeIds: typeIds ?? this.typeIds,
        categoryIds: categoryIds ?? this.categoryIds,
        tagIds: tagIds ?? this.tagIds,
        canonStatuses: canonStatuses ?? this.canonStatuses,
        knowledgeStatuses: knowledgeStatuses ?? this.knowledgeStatuses,
        includeArchived: includeArchived ?? this.includeArchived,
        onlyUnresolved: onlyUnresolved ?? this.onlyUnresolved,
        onlyConnected: onlyConnected ?? this.onlyConnected,
        sort: sort ?? this.sort,
      );

  ResearchFilter toggleType(String id) =>
      copyWith(typeIds: _toggle(typeIds, id));
  ResearchFilter toggleCategory(String id) =>
      copyWith(categoryIds: _toggle(categoryIds, id));
  ResearchFilter toggleTag(String id) => copyWith(tagIds: _toggle(tagIds, id));
  ResearchFilter toggleCanonStatus(CodexCanonStatus status) =>
      copyWith(canonStatuses: _toggle(canonStatuses, status));
  ResearchFilter toggleKnowledgeStatus(CodexKnowledgeStatus status) =>
      copyWith(knowledgeStatuses: _toggle(knowledgeStatuses, status));

  /// The equivalent Codex filter, so the shared service does the querying.
  ///
  /// When no type facet is selected the whole Research type set is requested,
  /// which is what scopes the Codex library down to Research Studio's records.
  CodexEntryFilter toCodexFilter() => CodexEntryFilter(
        query: query,
        templateIds:
            typeIds.isEmpty ? ResearchRecordTypes.typeIds : typeIds,
        categoryIds: categoryIds,
        tagIds: tagIds,
        canonStatuses: canonStatuses,
        knowledgeStatuses: knowledgeStatuses,
        includeArchived: includeArchived,
        sort: switch (sort) {
          ResearchSort.title => CodexEntrySort.title,
          ResearchSort.reliability => CodexEntrySort.recentlyUpdated,
          ResearchSort.recentlyUpdated => CodexEntrySort.recentlyUpdated,
        },
      );

  Map<String, Object?> toJson() => {
        'query': query,
        'typeIds': typeIds.toList()..sort(),
        'categoryIds': categoryIds.toList()..sort(),
        'tagIds': tagIds.toList()..sort(),
        'canonStatuses': canonStatuses.map((value) => value.name).toList()
          ..sort(),
        'knowledgeStatuses':
            knowledgeStatuses.map((value) => value.name).toList()..sort(),
        'includeArchived': includeArchived,
        'onlyUnresolved': onlyUnresolved,
        'onlyConnected': onlyConnected,
        'sort': sort.name,
      };

  factory ResearchFilter.fromJson(Map<String, Object?> json) => ResearchFilter(
        query: json['query'] as String? ?? '',
        typeIds: _stringList(json['typeIds']).toSet(),
        categoryIds: _stringList(json['categoryIds']).toSet(),
        tagIds: _stringList(json['tagIds']).toSet(),
        canonStatuses: _enumSet(CodexCanonStatus.values, json['canonStatuses']),
        knowledgeStatuses:
            _enumSet(CodexKnowledgeStatus.values, json['knowledgeStatuses']),
        includeArchived: json['includeArchived'] as bool? ?? false,
        onlyUnresolved: json['onlyUnresolved'] as bool? ?? false,
        onlyConnected: json['onlyConnected'] as bool? ?? false,
        sort: ResearchSort.values
                .where((value) => value.name == json['sort'])
                .firstOrNull ??
            ResearchSort.recentlyUpdated,
      );
}

/// One source, rolled up across every research item that cites it.
///
/// Built from the `sourceReferences` already stored on each record; the roll-up
/// itself is never written back.
class ResearchSourceUsage {
  const ResearchSourceUsage({
    required this.id,
    required this.label,
    required this.kind,
    required this.location,
    required this.itemIds,
  });

  final String id;
  final String label;
  final String kind;
  final String location;

  /// Research items citing this source, most recently updated first.
  final List<String> itemIds;

  int get usageCount => itemIds.length;
}

/// A record or manuscript node a research item may be connected to.
///
/// AuthorOS stores story entities as [AuthorRecord]s and manuscript chapters
/// and scenes as manuscript nodes. Both are connectable entities, so the
/// Research connection picker offers one list over the two. This is a display
/// view over entities that already exist; nothing here is persisted.
class ResearchConnectionTarget {
  const ResearchConnectionTarget({
    required this.id,
    required this.title,
    required this.typeId,
    required this.isManuscriptNode,
  });

  final String id;
  final String title;

  /// The record type id, or the manuscript node type (`chapter`, `scene`).
  final String typeId;

  final bool isManuscriptNode;
}

/// A research item's link to another AuthorOS record.
class ResearchConnectionView {
  const ResearchConnectionView({
    required this.linkId,
    required this.typeId,
    required this.label,
    required this.otherId,
    required this.otherTitle,
    required this.otherTypeId,
    required this.outgoing,
  });

  final String linkId;
  final String typeId;
  final String label;
  final String otherId;
  final String otherTitle;
  final String otherTypeId;

  /// True when the research item is the link's source.
  final bool outgoing;
}

/// Everything the Research dashboard renders, computed from stored records.
class ResearchDashboard {
  const ResearchDashboard({
    required this.items,
    required this.recent,
    required this.unresolved,
    required this.connectedItemIds,
    required this.sources,
    required this.categoryCounts,
    required this.tagCounts,
    required this.typeCounts,
    required this.archivedCount,
  });

  static const empty = ResearchDashboard(
    items: [],
    recent: [],
    unresolved: [],
    connectedItemIds: {},
    sources: [],
    categoryCounts: {},
    tagCounts: {},
    typeCounts: {},
    archivedCount: 0,
  );

  /// Active research items in the project.
  final List<CodexEntry> items;

  /// The most recently updated items, newest first.
  final List<CodexEntry> recent;

  /// Items [researchIsResolved] rejects.
  final List<CodexEntry> unresolved;

  /// Items linked to at least one other record in this project.
  final Set<String> connectedItemIds;

  final List<ResearchSourceUsage> sources;
  final Map<String, int> categoryCounts;
  final Map<String, int> tagCounts;
  final Map<String, int> typeCounts;
  final int archivedCount;

  int get itemCount => items.length;
  int get sourceCount => sources.length;
  int get categoryCount => categoryCounts.length;
  int get tagCount => tagCounts.length;
  int get unresolvedCount => unresolved.length;
  int get connectedCount => connectedItemIds.length;
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

List<String> _stringList(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];
