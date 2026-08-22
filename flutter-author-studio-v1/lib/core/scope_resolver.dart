import '../persistence/authoros_database.dart';
import 'connected_domain.dart';
import 'project_roster_entry.dart';
import 'starter_project.dart';
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
  /// Membership is read from the **project roster**, which owns series identity
  /// (Q-S1). The Codex consumes that id; it does not mint one and does not keep
  /// a second answer. `ProjectRows.series_id` is the truth and `series_rows` is
  /// what proves the series exists.
  ///
  /// A book with no roster row, or one naming a series that has been deleted,
  /// resolves to standalone rather than throwing. A missing series is a reason
  /// to show the author their own book, not to fail the Codex open — but see
  /// [membershipUnknown], because "standalone" and "the roster has not caught
  /// up" are different answers and only one of them is the author's intent.
  Future<ScopeChain> chain() async {
    final entry = await repository.projectRosterEntry(projectId);
    final seriesId = entry?.seriesId;
    if (seriesId == null || seriesId.trim().isEmpty) {
      return ScopeChain(projectId: projectId);
    }
    // The roster's own delete releases its books, so a dangling id should not
    // occur. It is still checked: a half-applied sync could leave one, and
    // silently inheriting from a series that no longer exists would be worse
    // than showing the book alone.
    if (await repository.seriesById(seriesId) == null) {
      return ScopeChain(projectId: projectId);
    }
    return ScopeChain(projectId: projectId, seriesId: seriesId);
  }

  /// Whether this book is absent from the roster entirely.
  ///
  /// Distinct from standalone, and the distinction matters: a book the roster
  /// has never seen resolves to standalone by [chain], which would quietly hide
  /// series canon from a book the author considers part of a series. Callers
  /// that can repair the roster should; callers that cannot should at least not
  /// report it as a deliberate choice.
  Future<bool> membershipUnknown() async =>
      await repository.projectRosterEntry(projectId) == null;

  /// The books enrolled in [seriesId], in series order.
  ///
  /// The roster is the membership authority, so this reads roster rows rather
  /// than `project`-typed records.
  Future<List<ProjectRosterEntry>> membersOf(String seriesId) =>
      repository.booksInSeries(seriesId);

  /// Ensures this book exists on the roster, so its membership has a home.
  ///
  /// Onboarding writes the shared-preferences pointer but no roster row, and
  /// the roster only adopts a legacy project when it is *entirely* empty. So a
  /// second book can exist to every Studio and be unknown to the roster — and
  /// under Q-S1 that would read as standalone and hide the series canon the
  /// author expects.
  ///
  /// Repairing it here is deliberate and narrow: it adds the book to the roster
  /// as **standalone**, which is the truthful default for a book nothing has
  /// ever placed in a series. It never invents membership, and it never
  /// overwrites an existing row.
  Future<void> ensureRosterEntry(StarterProject project) async {
    if (await repository.projectRosterEntry(project.id) != null) return;
    await repository.putProjectRosterEntry(
      ProjectRosterEntry.standalone(project),
    );
  }

  /// Ensures a `project` record exists for [projectId], and returns it.
  ///
  /// Distinct from [ensureRosterEntry]: the roster row is where *membership*
  /// lives, and this record is what lets the book own records and appear in the
  /// graph. Calling this again is a no-op — it never bumps a revision and never
  /// overwrites an author's title.
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
