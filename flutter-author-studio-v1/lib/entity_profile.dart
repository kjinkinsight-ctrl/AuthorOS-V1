import 'core/canon_facts.dart';
import 'core/connected_domain.dart';
import 'core/record_inspection.dart';

/// Where one entity is used inside one book.
class BookUsage {
  const BookUsage({
    required this.bookId,
    required this.bookTitle,
    required this.order,
    required this.chapters,
    this.appearance,
    this.stateRecordId,
  });

  final String bookId;
  final String bookTitle;
  final int order;

  /// The chapters and scenes inside this book that reference the entity.
  final List<ChapterUsage> chapters;

  /// The `appearsIn` link recording the book appearance, if the author made
  /// one. Its metadata carries role, status and first/last appearance.
  final RecordLink? appearance;

  /// The `entity-state` record for this book, if the entity differs here.
  final String? stateRecordId;

  int get sceneCount =>
      chapters.fold(0, (sum, chapter) => sum + chapter.scenes.length);

  bool get isEmpty => chapters.isEmpty && appearance == null;
}

/// Where one entity is used inside one chapter.
class ChapterUsage {
  const ChapterUsage({
    required this.chapterId,
    required this.chapterTitle,
    required this.scenes,
    this.reference,
  });

  final String chapterId;
  final String chapterTitle;

  /// The scenes inside this chapter that reference the entity.
  final List<ReferenceInspection> scenes;

  /// A reference to the chapter itself, when the entity is linked to the
  /// chapter rather than to one of its scenes.
  final ReferenceInspection? reference;
}

/// One group of non-manuscript usages — plot, timeline, map or research.
class UsageGroup {
  const UsageGroup({required this.kind, required this.references});

  final ReferenceKind kind;
  final List<ReferenceInspection> references;

  bool get isEmpty => references.isEmpty;
}

/// Everywhere one entity is used.
///
/// Assembled from a single [UniversalRecordInspection] rather than a second
/// walk of the edge table — the inspector already classifies every reference,
/// and a second traversal would be a second answer.
class EntityUsageReport {
  const EntityUsageReport({
    required this.recordId,
    required this.books,
    required this.unfiledChapters,
    required this.groups,
    required this.derived,
    this.ghostNodeIds = const [],
  });

  final String recordId;

  /// Usage grouped by book, in series order.
  final List<BookUsage> books;

  /// Chapters no book claims — every chapter, in a project without books.
  final List<ChapterUsage> unfiledChapters;

  /// Plot, timeline, map, research and anything else, by kind.
  final List<UsageGroup> groups;

  /// Names found in prose that nothing links yet.
  ///
  /// Kept in its own collection and never merged with the explicit usages
  /// above: a derived relationship is a suggestion, and presenting it beside a
  /// recorded one would blur what the author has actually decided.
  final List<DerivedUsage> derived;

  /// References pointing at manuscript nodes that no longer resolve.
  ///
  /// Manuscript nodes are upsert-only and never deleted, so deleting a scene
  /// leaves its node and any links behind. Surfacing them is better than
  /// silently counting them as real usage.
  final List<String> ghostNodeIds;

  List<UsageGroup> get nonEmptyGroups =>
      groups.where((group) => !group.isEmpty).toList();

  int get bookCount => books.where((book) => !book.isEmpty).length;

  int get sceneCount =>
      books.fold<int>(0, (sum, book) => sum + book.sceneCount) +
      unfiledChapters.fold<int>(0, (sum, each) => sum + each.scenes.length);

  bool get isEmpty =>
      books.every((book) => book.isEmpty) &&
      unfiledChapters.isEmpty &&
      nonEmptyGroups.isEmpty;
}

/// A name found in prose that nothing links yet.
class DerivedUsage {
  const DerivedUsage({
    required this.nodeId,
    required this.nodeTitle,
    required this.matchedName,
    required this.snippet,
    this.bookId,
  });

  final String nodeId;
  final String nodeTitle;
  final String matchedName;
  final String snippet;
  final String? bookId;
}

/// One section of an entity's profile.
class ProfileSection {
  const ProfileSection({
    required this.id,
    required this.title,
    required this.entries,
  });

  final String id;
  final String title;
  final List<ProfileEntry> entries;

  bool get isEmpty => entries.isEmpty;
}

/// One line in a profile section.
class ProfileEntry {
  const ProfileEntry({
    required this.label,
    this.detail = '',
    this.recordId,
    this.nodeId,
  });

  final String label;
  final String detail;
  final String? recordId;
  final String? nodeId;
}

/// One entity, everything it is, everywhere it is used.
///
/// A read composition over the services that already own each part: the
/// inspector for connections and references, SeriesService for books,
/// CanonConflictAnalyzer for conflicts, EntitySuggestionService for what the
/// prose mentions. It owns nothing and writes nothing.
class EntityProfile {
  const EntityProfile({
    required this.record,
    required this.typeName,
    required this.aliases,
    required this.sections,
    required this.usage,
    required this.canonStatus,
    required this.confidence,
    required this.conflictCount,
    this.seriesTitle,
    this.bookTitles = const [],
  });

  final AuthorRecord record;
  final String typeName;
  final List<String> aliases;

  /// Relationships, locations, timeline, appearances, research and notes.
  final List<ProfileSection> sections;

  final EntityUsageReport usage;

  /// The record's canon status as a fact status, showing `contradicted` when
  /// something disagrees with it.
  final CanonFactStatus canonStatus;

  /// How far to trust this entity's canon overall, 0 to 1.
  final double confidence;

  final int conflictCount;

  final String? seriesTitle;
  final List<String> bookTitles;

  String get id => record.id;
  String get title => record.title;

  List<ProfileSection> get nonEmptySections =>
      sections.where((section) => !section.isEmpty).toList();
}
