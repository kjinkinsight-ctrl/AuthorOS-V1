/// The project roster — the domain layer.
///
/// A [ProjectRosterEntry] is one project as the roster knows it: the project
/// itself, and — when it is a book rather than a standalone novel — which
/// series it belongs to and where it sits in that series.
///
/// It carries no title and no word target of its own. Both live on the
/// [StarterProject] it wraps, which is the only place either is defined.
///
/// Presentation-independent: nothing here imports Flutter, and this lives in
/// `core/` so the persistence layer can store a roster entry without importing
/// the onboarding widgets.
library;

import 'starter_project.dart';

/// One project on the author's roster.
class ProjectRosterEntry {
  const ProjectRosterEntry({
    required this.project,
    this.seriesId,
    this.seriesPosition,
    this.createdAt,
    this.updatedAt,
  });

  /// A standalone project — on the roster, in no series.
  factory ProjectRosterEntry.standalone(StarterProject project) =>
      ProjectRosterEntry(project: project);

  final StarterProject project;

  /// The series this project is a book of, or `null` when it stands alone.
  /// AuthorOS must keep supporting the novelist who will never write a series.
  final String? seriesId;

  /// Zero-based position within the series, so "Book 1" is position 0.
  /// `null` exactly when [seriesId] is null.
  final int? seriesPosition;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get projectId => project.id;

  /// The project's title, read from the project itself.
  String get title => project.title;

  /// The book's word target: the project's own goal, which is what
  /// `AnalyticsSummary.targetWordCount` already reads. A series never stores a
  /// second copy of this number.
  int get targetWords => project.wordGoal < 0 ? 0 : project.wordGoal;

  /// Whether this project is a book in a series rather than a standalone.
  bool get isBook => seriesId != null;

  /// Human-facing book number: position 0 is "Book 1". `null` when standalone.
  int? get bookNumber => seriesPosition == null ? null : seriesPosition! + 1;

  ProjectRosterEntry copyWith({
    StarterProject? project,
    String? seriesId,
    int? seriesPosition,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ProjectRosterEntry(
        project: project ?? this.project,
        seriesId: seriesId ?? this.seriesId,
        seriesPosition: seriesPosition ?? this.seriesPosition,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// The same entry with no series membership.
  ///
  /// A separate method rather than `copyWith(seriesId: null)`, because
  /// `copyWith` cannot tell "leave it alone" from "clear it".
  ProjectRosterEntry withoutSeries() => ProjectRosterEntry(
        project: project,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// The same entry placed in a series at [position].
  ProjectRosterEntry inSeries(String seriesId, int position) =>
      ProjectRosterEntry(
        project: project,
        seriesId: seriesId,
        seriesPosition: position < 0 ? 0 : position,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  String toString() => 'ProjectRosterEntry(${project.id}, '
      '${seriesId == null ? 'standalone' : 'book $bookNumber of $seriesId'})';
}
