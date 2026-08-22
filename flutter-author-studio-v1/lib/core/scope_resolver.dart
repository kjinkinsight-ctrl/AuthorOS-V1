import '../persistence/authoros_database.dart';
import 'connected_domain.dart';
import 'record_service.dart';

/// The built-in record types that carry the scope hierarchy.
///
/// Both have been registered in `BuiltInRecordTypes` since the Universal
/// Records foundation landed. Nothing here adds a record type; this file
/// finally instantiates one.
const String kProjectRecordTypeId = 'project';
const String kSeriesRecordTypeId = 'series';

/// The record types that hold other records rather than describe the world.
///
/// A book and a series are containers: they carry scope, not lore. Studios that
/// list or link *entries* exclude them for the same reason
/// `kNonGraphRecordTypeIds` excludes the graph's own canvas — presenting a
/// container beside the things it contains is a category error, not a filter
/// the author should have to apply.
const Set<String> kScopeContainerTypeIds = {
  kProjectRecordTypeId,
  kSeriesRecordTypeId,
};

/// One project's position in `Universe -> Series -> Project`.
///
/// The chain is the only answer to "what may this project read?" in the
/// application. Adding the universe tier extends this class; it does not
/// introduce a second resolution path.
class ScopeChain {
  const ScopeChain({required this.projectId, this.seriesId});

  final String projectId;
  final String? seriesId;

  /// A project that belongs to no series.
  ///
  /// Progressive complexity depends on this: an author who writes standalone
  /// books never sees a control for a concept they do not have.
  bool get isStandalone => seriesId == null;

  /// The scopes this project inherits records from.
  Set<String> get inheritedScopeIds => {if (seriesId != null) seriesId!};

  /// Every scope whose records this project may read, its own included.
  Set<String> get visibleScopeIds => {projectId, ...inheritedScopeIds};

  ScopeChain copyWith({String? seriesId, bool clearSeries = false}) =>
      ScopeChain(
        projectId: projectId,
        seriesId: clearSeries ? null : (seriesId ?? this.seriesId),
      );
}

/// Resolves a project's scope chain.
///
/// Membership lives on the project's own record, in the indexed `series_id`
/// column that `AuthorRecordRows` has carried since schema version 6. Two
/// alternatives were rejected:
///
/// * A `partOfSeries` [RecordLink]. Every edge is bound to one project by
///   `ConnectionEngine.connect` and `RelationshipValidator`, so an edge from a
///   project to a series scope cannot be written without relaxing that
///   isolation rule — a far larger and more dangerous change than reading a
///   column that already exists.
/// * A membership list inside the series record's `fields` JSON. That is
///   unindexed, needs a full type scan to answer a per-project question, and
///   would put containment somewhere `StoryGraphFilter`, the search index and
///   `RecordVersion` cannot see.
///
/// This service owns no storage. The project record is written through
/// [RecordService], so enrolling a book in a series is versioned and audited
/// like every other change.
class ScopeResolver {
  const ScopeResolver({required this.projectId, required this.repository});

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  /// The chain for [projectId].
  ///
  /// A project with no record, or one naming a series that no longer exists,
  /// resolves to standalone rather than throwing. A missing series is a reason
  /// to show the author their own book, not to fail the Codex open.
  Future<ScopeChain> chain() async {
    final project = await repository.recordById(projectId);
    final seriesId = project?.seriesId;
    if (seriesId == null || seriesId.trim().isEmpty) {
      return ScopeChain(projectId: projectId);
    }
    final series = await repository.recordById(seriesId);
    if (series == null ||
        series.typeId != kSeriesRecordTypeId ||
        series.status == AuthorRecordStatus.deleted) {
      return ScopeChain(projectId: projectId);
    }
    return ScopeChain(projectId: projectId, seriesId: seriesId);
  }

  /// The project records enrolled in [seriesId].
  Future<List<AuthorRecord>> membersOf(String seriesId) =>
      repository.projectsInSeries(seriesId);

  /// Ensures a `project` record exists for [projectId], and returns it.
  ///
  /// The application's project identity comes from onboarding and lives in
  /// shared preferences; nothing has ever written it to the record store. The
  /// scope chain needs somewhere indexed to hang membership, so the first
  /// Codex open materialises the record. Calling this again is a no-op — it
  /// never bumps a revision and never overwrites an author's title.
  Future<AuthorRecord> ensureProjectRecord({
    String title = '',
    DateTime? timestamp,
  }) async {
    final existing = await repository.recordById(projectId);
    if (existing != null) return existing;
    final now = (timestamp ?? DateTime.now()).toUtc();
    final name = title.trim().isEmpty ? 'This book' : title.trim();
    final record = AuthorRecord(
      id: projectId,
      typeId: kProjectRecordTypeId,
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: name,
      canonStatus: CanonStatus.canon,
      templateId: kProjectRecordTypeId,
      fields: {'name': name},
      createdAt: now,
      updatedAt: now,
    );
    return records.createRecord(record);
  }
}
