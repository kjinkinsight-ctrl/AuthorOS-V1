import 'connected_domain.dart';
import 'dart:convert';

enum SearchEntityKind { record, manuscriptNode, branchRecord }

enum SearchDestination {
  characterStudio,
  worldStudio,
  storyCodex,
  timelineStudio,
  plotStudio,
  manuscriptStudio,
  seriesStudio,
  knowledgeGraph,
  record,
}

class SearchNavigationTarget {
  const SearchNavigationTarget({
    required this.destination,
    required this.recordId,
    required this.projectId,
    this.branchId,
  });

  final SearchDestination destination;
  final String recordId;
  final String projectId;
  final String? branchId;
}

class UniversalSearchFilter {
  const UniversalSearchFilter({
    required this.projectId,
    this.recordType,
    this.seriesId,
    this.bookId,
    this.branchId,
    this.canonStatus,
    this.lifecycleStatus,
    this.limit = 100,
  });

  final String projectId;
  final String? recordType;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final CanonStatus? canonStatus;
  final AuthorRecordStatus? lifecycleStatus;
  final int limit;

  UniversalSearchFilter copyWith({
    String? recordType,
    String? seriesId,
    String? bookId,
    String? branchId,
    CanonStatus? canonStatus,
    AuthorRecordStatus? lifecycleStatus,
  }) =>
      UniversalSearchFilter(
        projectId: projectId,
        recordType: recordType ?? this.recordType,
        seriesId: seriesId ?? this.seriesId,
        bookId: bookId ?? this.bookId,
        branchId: branchId ?? this.branchId,
        canonStatus: canonStatus ?? this.canonStatus,
        lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
        limit: limit,
      );
}

class SearchResult {
  const SearchResult({
    required this.recordId,
    required this.recordType,
    required this.title,
    required this.snippet,
    required this.projectId,
    required this.canonStatus,
    required this.navigationTarget,
    required this.relevance,
    this.seriesId,
    this.bookId,
    this.branchId,
    this.templateId,
    this.category,
    this.tags = const [],
    this.matchedField,
  });

  final String recordId;
  final String recordType;
  final String title;
  final String snippet;
  final String projectId;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final CanonStatus canonStatus;
  final String? templateId;
  final String? category;
  final List<String> tags;
  final String? matchedField;
  final double relevance;
  final SearchNavigationTarget navigationTarget;
}

class SearchIndexHit {
  const SearchIndexHit({
    required this.entityId,
    required this.kind,
    required this.title,
    required this.snippet,
    required this.rank,
    this.matchedField,
  });

  final String entityId;
  final SearchEntityKind kind;
  final String title;
  final String snippet;
  final double rank;
  final String? matchedField;
}

String branchSearchEntityId(String branchId, String recordId) =>
    'branch-record:${_encodeSearchId(branchId)}:${_encodeSearchId(recordId)}';

({String branchId, String recordId})? parseBranchSearchEntityId(String value) {
  final parts = value.split(':');
  if (parts.length != 3 || parts.first != 'branch-record') return null;
  try {
    return (
      branchId: _decodeSearchId(parts[1]),
      recordId: _decodeSearchId(parts[2]),
    );
  } on FormatException {
    return null;
  }
}

String _encodeSearchId(String value) =>
    base64Url.encode(utf8.encode(value)).replaceAll('=', '');

String _decodeSearchId(String value) => utf8.decode(
      base64Url.decode(base64Url.normalize(value)),
    );
