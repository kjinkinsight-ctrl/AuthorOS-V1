/// The project roster — the storage layer.
///
/// Mirrors [WritingGoalsStore]: it owns no arithmetic and no screen, it moves
/// projects and series between the canonical repository and its callers.
///
/// It exists so AuthorOS can hold more than one book. Before the roster, one
/// project lived in a single preferences key and saving a second overwrote the
/// first. The roster is deliberately **additive**: that key survives untouched
/// as the pointer to whichever project is currently open, and this store is
/// the durable list of every project that exists. An install that never opens
/// the Projects Studio behaves exactly as it did before.
library;

import 'core/project_roster_entry.dart';
import 'core/writing_series.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';

/// Reads and writes the author's projects and series.
class ProjectRosterStore {
  const ProjectRosterStore({
    DriftConnectedDomainRepository? repository,
    this.onboardingStore = const OnboardingStore(),
  }) : _repository = repository;

  final DriftConnectedDomainRepository? _repository;

  /// How the currently-open project is read. The roster does not own that
  /// pointer; it only adopts what the pointer names.
  final OnboardingStore onboardingStore;

  DriftConnectedDomainRepository get repository =>
      _repository ?? authorOsRepository;

  /// Every project on the roster, newest first, adopting the legacy project
  /// first if it has not been adopted yet.
  Future<List<ProjectRosterEntry>> load() async {
    await _adoptLegacyProject();
    return repository.projectRoster();
  }

  /// Brings the project stored under the pre-roster preferences key onto the
  /// roster, once.
  ///
  /// Installs that predate the roster have exactly one project, saved by
  /// [OnboardingStore]. Without this it would be invisible in a Projects
  /// Studio that lists the roster — the author's only book, missing.
  ///
  /// Keyed by project id and skipped when an entry already exists, so repeated
  /// loads never duplicate it, and an author who later removed the project
  /// from the roster does not have it silently reappear on every read... which
  /// is why the guard is "the roster is empty", not "this id is absent".
  Future<void> _adoptLegacyProject() async {
    final existing = await repository.projectRoster();
    if (existing.isNotEmpty) return;
    final legacy = await onboardingStore.loadProject();
    if (legacy == null) return;
    await repository.putProjectRosterEntry(
      ProjectRosterEntry.standalone(legacy),
    );
  }

  /// Adds a project to the roster, or updates the one already stored under its
  /// id. Series membership is preserved: saving an edited book does not knock
  /// it out of its series.
  Future<ProjectRosterEntry> save(StarterProject project) async {
    final existing = await repository.projectRosterEntry(project.id);
    final entry = ProjectRosterEntry(
      project: project,
      seriesId: existing?.seriesId,
      seriesPosition: existing?.seriesPosition,
      createdAt: existing?.createdAt,
      updatedAt: DateTime.now(),
    );
    await repository.putProjectRosterEntry(entry);
    return entry;
  }

  /// Takes a project off the roster.
  ///
  /// Roster-only, and deliberately so: the manuscript, records and writing
  /// history stay exactly where they are. Removing a project from a list must
  /// never be a way to destroy an author's writing.
  Future<void> remove(String projectId) async {
    await repository.deleteProjectRosterEntry(projectId);
  }

  Future<List<WritingSeries>> allSeries() => repository.allSeries();

  Future<WritingSeries?> seriesById(String seriesId) =>
      repository.seriesById(seriesId);

  /// Normalizes and stores a series, returning exactly what was stored.
  Future<WritingSeries> saveSeries(WritingSeries series) async {
    final normalized = series.normalized().copyWith(updatedAt: DateTime.now());
    await repository.putSeries(normalized);
    return normalized;
  }

  /// Removes a series; its books become standalone projects again.
  Future<void> deleteSeries(String seriesId) async {
    await repository.deleteSeries(seriesId);
  }

  /// The books of one series, in order.
  Future<List<ProjectRosterEntry>> books(String seriesId) =>
      repository.booksInSeries(seriesId);

  /// The series a project belongs to, or `null` when it stands alone.
  Future<WritingSeries?> seriesForProject(String projectId) async {
    final entry = await repository.projectRosterEntry(projectId);
    final seriesId = entry?.seriesId;
    if (seriesId == null) return null;
    return repository.seriesById(seriesId);
  }

  /// Puts a project into a series, at [position] or at the end.
  ///
  /// The book's target comes from the series' default when the book has none
  /// of its own, and is otherwise left alone: joining a series must not
  /// silently rewrite a target the author already chose. The target itself
  /// stays on the project, because `StarterProject.wordGoal` is the one place
  /// a book's target is defined.
  Future<ProjectRosterEntry> addBookToSeries({
    required String projectId,
    required String seriesId,
    int? position,
  }) async {
    final entry = await repository.projectRosterEntry(projectId);
    if (entry == null) {
      throw StateError('Project $projectId is not on the roster.');
    }
    final series = await repository.seriesById(seriesId);
    if (series == null) {
      throw StateError('Series $seriesId does not exist.');
    }

    final books = await repository.booksInSeries(seriesId);
    final others = books.where((book) => book.projectId != projectId).toList();
    final target = position == null
        ? others.length
        : position.clamp(0, others.length);

    final seeded = entry.targetWords > 0 || !series.hasDefaultTarget
        ? entry.project
        : entry.project.copyWith(wordGoal: series.defaultTargetWords);

    final ordered = [...others]
      ..insert(target, entry.copyWith(project: seeded));
    await _writePositions(seriesId, ordered);

    return (await repository.projectRosterEntry(projectId))!;
  }

  /// Takes a book out of its series. The project itself is untouched and
  /// remains on the roster as a standalone.
  Future<void> removeBookFromSeries(String projectId) async {
    final entry = await repository.projectRosterEntry(projectId);
    final seriesId = entry?.seriesId;
    if (entry == null || seriesId == null) return;

    await repository.putProjectRosterEntry(
      entry.withoutSeries().copyWith(updatedAt: DateTime.now()),
    );

    // Close the gap the departing book left behind.
    final remaining = await repository.booksInSeries(seriesId);
    await _writePositions(seriesId, remaining);
  }

  /// Reorders a series to match [orderedProjectIds].
  ///
  /// Ids that are not books of this series are ignored, and books the caller
  /// omitted keep their relative order at the end, so a stale list from a
  /// screen can never drop a book out of its series.
  Future<void> reorderBooks(
    String seriesId,
    List<String> orderedProjectIds,
  ) async {
    final books = await repository.booksInSeries(seriesId);
    final byId = {for (final book in books) book.projectId: book};

    final ordered = <ProjectRosterEntry>[];
    for (final id in orderedProjectIds) {
      final book = byId.remove(id);
      if (book != null) ordered.add(book);
    }
    ordered.addAll(books.where((book) => byId.containsKey(book.projectId)));

    await _writePositions(seriesId, ordered);
  }

  /// Writes positions densely from zero, so the sequence never develops gaps
  /// or ties however the books were moved about.
  Future<void> _writePositions(
    String seriesId,
    List<ProjectRosterEntry> ordered,
  ) async {
    final now = DateTime.now();
    for (var index = 0; index < ordered.length; index++) {
      await repository.putProjectRosterEntry(
        ordered[index].inSeries(seriesId, index).copyWith(updatedAt: now),
      );
    }
  }
}
