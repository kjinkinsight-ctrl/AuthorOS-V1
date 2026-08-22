/// Puts a book in a series the way the Projects Studio does.
///
/// Series identity belongs to the project roster (Q-S1), so a test that wants a
/// book to be part of a series has to say so where the author would — in
/// `series_rows` and `project_rows` — not by asking the Codex to invent one.
/// Writing through the repository rather than `ProjectRosterStore` keeps these
/// tests off shared preferences and off the sync recorder.
library;

import 'package:author_studio_v1/core/project_roster_entry.dart';
import 'package:author_studio_v1/core/starter_project.dart';
import 'package:author_studio_v1/core/writing_series.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';

StarterProject starterProject(String id, {String title = 'A Book'}) =>
    StarterProject(
      id: id,
      title: title,
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 80000,
      acts: const [],
      chapters: const [],
      characterSheets: const [],
      beatChecklist: const [],
      firstSceneTitle: 'Opening Scene',
    );

/// Creates [seriesId] on the roster and enrols [projectIds] in order.
Future<WritingSeries> enrolInSeries(
  DriftConnectedDomainRepository repository, {
  required String seriesId,
  required List<String> projectIds,
  String name = 'The Endovier Cycle',
  DateTime? timestamp,
}) async {
  final now = timestamp ?? DateTime.utc(2026, 8, 22);
  final series = WritingSeries(
    id: seriesId,
    name: name,
    defaultTargetWords: WritingSeries.defaultTargetWordsSeed,
    createdAt: now,
    updatedAt: now,
  );
  await repository.putSeries(series);
  for (var index = 0; index < projectIds.length; index += 1) {
    await repository.putProjectRosterEntry(
      ProjectRosterEntry(
        project: starterProject(projectIds[index]),
        seriesId: seriesId,
        seriesPosition: index,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
  return series;
}

/// Puts [projectId] on the roster with no series, which is how a standalone
/// book looks to the resolver.
Future<void> enrolStandalone(
  DriftConnectedDomainRepository repository,
  String projectId, {
  DateTime? timestamp,
}) async {
  final now = timestamp ?? DateTime.utc(2026, 8, 22);
  await repository.putProjectRosterEntry(
    ProjectRosterEntry(
      project: starterProject(projectId),
      createdAt: now,
      updatedAt: now,
    ),
  );
}
