/// World Board Phase 1 — the aggregation layer.
///
/// This service owns no storage. It asks the layers that already own each
/// number for what they hold, and folds the answers into one
/// [WorldBoardSnapshot].
///
/// Every aggregate the Analytics Studio also reports — words, chapters,
/// scenes, characters, timeline events, plot records, the writing goal and
/// the progress toward it — comes back from [AnalyticsService] as a single
/// [AnalyticsSummary]. The board renders those values; it does not re-derive
/// them. That is what makes it impossible for the two screens to disagree
/// about the same metric.
///
/// What is left here is the board's own material: the World Studio's records,
/// which analytics does not report, the record titles that populate the
/// relationship map, and the shared audit history behind the activity feed.
library;

import '../analytics_service.dart';
import '../core/connected_domain.dart';
import '../core/version_audit.dart';
import '../core/version_audit_service.dart';
import '../manuscript_store.dart';
import '../onboarding.dart';
import '../persistence/authoros_database.dart';
import '../plot_service.dart';
import '../timeline_service.dart';
import '../world_service.dart';
import 'world_board_models.dart';

/// Gathers the active project's ecosystem from the existing AuthorOS services.
class WorldBoardService {
  WorldBoardService({
    required this.project,
    DriftConnectedDomainRepository? repository,
    this.manuscriptStore = const ManuscriptStore(),
    AnalyticsService? analytics,
    this.branchSampleSize = 3,
    this.activityLimit = 6,
  })  : _repository = repository,
        _analytics = analytics,
        assert(
          analytics == null || analytics.project.id == project.id,
          "World Board analytics must be scoped to the board's own project.",
        );

  /// The project the shell currently has open. AuthorOS is single-project, so
  /// this is also the whole of the author's world today.
  final StarterProject project;

  final DriftConnectedDomainRepository? _repository;

  final AnalyticsService? _analytics;

  /// Reused rather than re-implemented: the manuscript's word, chapter, and
  /// scene counts are the Manuscript Studio's to define, and the Analytics
  /// Studio's to aggregate.
  final ManuscriptStore manuscriptStore;

  /// How many real record titles each branch samples for the relationship map.
  final int branchSampleSize;

  /// How many audit entries the recent-activity panel shows.
  final int activityLimit;

  DriftConnectedDomainRepository get repository =>
      _repository ?? authorOsRepository;

  /// The canonical analytics layer for [project].
  ///
  /// Injectable so tests can hand the board a service they control, and
  /// scoped to the same project and repository by default so the board can
  /// never end up reading another project's numbers.
  AnalyticsService get analytics =>
      _analytics ??
      AnalyticsService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      );

  /// The character record type, as the Characters Studio defines it. Taken
  /// from [AnalyticsService] rather than restated, so the board's cast and
  /// the analytics cast can never mean two different things.
  static const characterTypeId = AnalyticsService.characterTypeId;

  WorldService get worlds =>
      WorldService(projectId: project.id, repository: repository);

  TimelineService get timeline =>
      TimelineService(projectId: project.id, repository: repository);

  PlotService get plot =>
      PlotService(projectId: project.id, repository: repository);

  VersionAuditService get history =>
      VersionAuditService(projectId: project.id, repository: repository);

  /// Loads everything the board renders.
  ///
  /// The analytics summary supplies every shared aggregate. The record
  /// queries that follow exist only to name things — the relationship map
  /// shows real titles — and the counts beside those names still come from
  /// the summary. The queries run in turn: they share one database
  /// connection, and a board that opens in a few milliseconds does not need
  /// to race them.
  Future<WorldBoardSnapshot> load({DateTime? now}) async {
    final analyticsService = analytics;
    final summary = await analyticsService.getSummary();
    // The manuscript is read again only for its chapter titles; every
    // manuscript figure on the board comes from [summary].
    final manuscript = await analyticsService.loadManuscript();

    final characters = await _activeCharacters();
    final worldRecords = await worlds.worldRecords(includeArchived: false);
    final timelineRecords = _active(await timeline.query.all());
    final plotRecords = _active(await plot.query.all());
    final activity = await _recentActivity();

    final context = WorldBoardProjectContext(
      projectId: summary.projectId,
      title: summary.projectName,
      genre: project.genre,
      projectType: project.projectType,
      wordCount: summary.totalWordCount,
      wordGoal: summary.targetWordCount,
      chapterCount: summary.chapterCount,
      sceneCount: summary.sceneCount,
      // A project without a writing target reports no progress rather than a
      // false 100%; analytics says so by returning null, and the board shows
      // an empty bar.
      progress: summary.progressTowardTarget ?? 0,
      wordsRemaining: summary.wordsRemaining ?? 0,
    );

    final branches = <WorldBoardBranch>[
      _branch(
        WorldBoardSection.manuscript,
        summary.chapterCount,
        _chapterTitles(manuscript),
      ),
      _branch(
        WorldBoardSection.characters,
        summary.characterCount,
        _titles(characters),
      ),
      _branch(
        WorldBoardSection.worlds,
        worldRecords.length,
        _titles(worldRecords),
      ),
      _branch(
        WorldBoardSection.timelines,
        summary.timelineEventCount,
        _titles(timelineRecords),
      ),
      _branch(
        WorldBoardSection.plot,
        summary.plotRecordCount,
        _titles(plotRecords),
      ),
    ];

    return WorldBoardSnapshot(
      project: context,
      metrics: {
        WorldBoardSection.projects: WorldBoardMetric(
          section: WorldBoardSection.projects,
          count: 1,
          value: '1',
          caption: project.projectType,
        ),
        WorldBoardSection.manuscript: WorldBoardMetric(
          section: WorldBoardSection.manuscript,
          // A manuscript with no words and no chapters has not been started,
          // and the tile should say so rather than show a confident "0 words".
          count: summary.totalWordCount + summary.chapterCount,
          value: formatWorldBoardCount(summary.totalWordCount),
          caption: _manuscriptCaption(summary),
        ),
        WorldBoardSection.characters: _countMetric(
          WorldBoardSection.characters,
          summary.characterCount,
          'in this project',
        ),
        // Worlds are the one section analytics does not report: the Analytics
        // Studio has no world-building panel, so there is no shared metric to
        // consume and nothing to keep in step. The count stays the World
        // Studio's, read through its own service.
        WorldBoardSection.worlds: _countMetric(
          WorldBoardSection.worlds,
          worldRecords.length,
          'locations, maps, and routes',
        ),
        WorldBoardSection.timelines: _countMetric(
          WorldBoardSection.timelines,
          summary.timelineEventCount,
          'chronology records',
        ),
        WorldBoardSection.plot: _countMetric(
          WorldBoardSection.plot,
          summary.plotRecordCount,
          'arcs, beats, and threads',
        ),
      },
      branches: branches,
      activity: activity,
    );
  }

  /// Characters as the Characters Studio lists them, read here only for their
  /// titles: how many there are is [AnalyticsSummary.characterCount]'s answer.
  Future<List<AuthorRecord>> _activeCharacters() async {
    final records = await repository.recordsByTypeAndScope(
      typeId: characterTypeId,
      scopeId: project.id,
    );
    return _active(records);
  }

  Future<List<WorldBoardActivity>> _recentActivity() async {
    final events = await history.getAuditHistory();
    // The audit history comes back oldest first; the board reads newest first.
    final ordered = events.reversed.take(activityLimit);
    return [
      for (final event in ordered)
        WorldBoardActivity(
          id: event.id,
          summary: event.summary,
          changeLabel: _changeLabel(event.changeType),
          occurredAt: event.createdAt,
        ),
    ];
  }

  List<AuthorRecord> _active(List<AuthorRecord> records) => records
      .where((record) => record.status != AuthorRecordStatus.deleted)
      .toList();

  WorldBoardMetric _countMetric(
    WorldBoardSection section,
    int count,
    String caption,
  ) =>
      WorldBoardMetric(
        section: section,
        count: count,
        value: formatWorldBoardCount(count),
        caption: count == 0 ? '' : caption,
      );

  /// [count] is the section's total as analytics reports it; [titles] only
  /// decides which names the branch shows.
  WorldBoardBranch _branch(
    WorldBoardSection section,
    int count,
    List<String> titles,
  ) =>
      WorldBoardBranch(
        section: section,
        count: count,
        leaves: titles.take(branchSampleSize).toList(),
      );

  /// Most recently touched first, so the branch samples show live work.
  List<String> _titles(List<AuthorRecord> records) {
    final ordered = [...records]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return [for (final record in ordered) record.title];
  }

  List<String> _chapterTitles(ManuscriptProjectSummary manuscript) =>
      [for (final chapter in manuscript.chapters) chapter.title];

  String _manuscriptCaption(AnalyticsSummary summary) {
    if (summary.chapterCount == 0) return '';
    final chapters =
        '${summary.chapterCount} chapter${summary.chapterCount == 1 ? '' : 's'}';
    final scenes =
        '${summary.sceneCount} scene${summary.sceneCount == 1 ? '' : 's'}';
    return '$chapters · $scenes';
  }

  String _changeLabel(AuditChangeType type) => switch (type) {
        AuditChangeType.created => 'Created',
        AuditChangeType.updated => 'Updated',
        AuditChangeType.renamed => 'Renamed',
        AuditChangeType.archived => 'Archived',
        AuditChangeType.restored => 'Restored',
        AuditChangeType.deleted => 'Deleted',
        AuditChangeType.duplicated => 'Duplicated',
        AuditChangeType.connectionAdded => 'Connected',
        AuditChangeType.connectionRemoved => 'Disconnected',
        AuditChangeType.connectionMetadataChanged => 'Connection updated',
        AuditChangeType.connectionTypeChanged => 'Connection retyped',
        AuditChangeType.templateChanged => 'Template changed',
        AuditChangeType.statusChanged => 'Status changed',
        AuditChangeType.scopeChanged => 'Scope changed',
        AuditChangeType.branchChanged => 'Branch changed',
      };
}
