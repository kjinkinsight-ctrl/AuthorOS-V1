/// World Board Phase 1 — the aggregation layer.
///
/// This service owns no storage. It asks the Studios that already own each
/// domain — manuscript, characters, world, timeline, plot — for what they
/// hold, and folds the answers into one [WorldBoardSnapshot].
///
/// The rule that keeps the board honest: every number it reports has to come
/// back from one of those services. Nothing here invents a record, a count, or
/// a second definition of "what a character is".
library;

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
  const WorldBoardService({
    required this.project,
    DriftConnectedDomainRepository? repository,
    this.manuscriptStore = const ManuscriptStore(),
    this.branchSampleSize = 3,
    this.activityLimit = 6,
  }) : _repository = repository;

  /// The project the shell currently has open. AuthorOS is single-project, so
  /// this is also the whole of the author's world today.
  final StarterProject project;

  final DriftConnectedDomainRepository? _repository;

  /// Reused rather than re-implemented: the manuscript's word, chapter, and
  /// scene counts are the Manuscript Studio's to define.
  final ManuscriptStore manuscriptStore;

  /// How many real record titles each branch samples for the relationship map.
  final int branchSampleSize;

  /// How many audit entries the recent-activity panel shows.
  final int activityLimit;

  DriftConnectedDomainRepository get repository =>
      _repository ?? authorOsRepository;

  /// The character record type, as the Characters Studio defines it. Kept
  /// identical so the board's count and that Studio's list never disagree.
  static const characterTypeId = 'character';

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
  /// The record queries run in turn: they share one database connection, and
  /// a board that opens in a few milliseconds does not need to race them. The
  /// manuscript is read separately because it does not live in the record
  /// repository.
  Future<WorldBoardSnapshot> load({DateTime? now}) async {
    final manuscript = await _loadManuscript();

    final characters = await _activeCharacters();
    final worldRecords = await worlds.worldRecords(includeArchived: false);
    final timelineRecords = _active(await timeline.query.all());
    final plotRecords = _active(await plot.query.all());
    final activity = await _recentActivity();

    final context = WorldBoardProjectContext(
      projectId: project.id,
      title: project.title,
      genre: project.genre,
      projectType: project.projectType,
      wordCount: manuscript.wordCount,
      wordGoal: project.wordGoal,
      chapterCount: manuscript.chapterCount,
      sceneCount: manuscript.sceneCount,
    );

    final branches = <WorldBoardBranch>[
      _branch(WorldBoardSection.manuscript, _chapterTitles(manuscript)),
      _branch(WorldBoardSection.characters, _titles(characters)),
      _branch(WorldBoardSection.worlds, _titles(worldRecords)),
      _branch(WorldBoardSection.timelines, _titles(timelineRecords)),
      _branch(WorldBoardSection.plot, _titles(plotRecords)),
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
          count: manuscript.wordCount + manuscript.chapterCount,
          value: formatWorldBoardCount(manuscript.wordCount),
          caption: _manuscriptCaption(manuscript),
        ),
        WorldBoardSection.characters: _countMetric(
          WorldBoardSection.characters,
          characters.length,
          'in this project',
        ),
        WorldBoardSection.worlds: _countMetric(
          WorldBoardSection.worlds,
          worldRecords.length,
          'locations, maps, and routes',
        ),
        WorldBoardSection.timelines: _countMetric(
          WorldBoardSection.timelines,
          timelineRecords.length,
          'chronology records',
        ),
        WorldBoardSection.plot: _countMetric(
          WorldBoardSection.plot,
          plotRecords.length,
          'arcs, beats, and threads',
        ),
      },
      branches: branches,
      activity: activity,
    );
  }

  /// Reads the manuscript through the Manuscript Studio's own store, seeded
  /// exactly the way the Statistics Studio seeds it, so both screens report
  /// the same word count for the same project.
  Future<ManuscriptProjectSummary> _loadManuscript() async {
    final migrated = await manuscriptStore.loadLegacyChapterSeeds(project.id);
    final seeds = migrated.isNotEmpty
        ? migrated
        : project.chapters
            .map(
              (chapter) => ManuscriptChapterSeed(
                title: chapter.title,
                prompt: chapter.prompt,
                status: chapter.status,
                scenes: chapter.scenes,
                linkedChapterIds: chapter.linkedChapterIds,
              ),
            )
            .toList();
    return manuscriptStore.loadStudio(
      project.id,
      manuscriptTitle: project.title,
      defaultChapters: seeds,
      firstSceneTitle: project.firstSceneTitle,
    );
  }

  /// Characters as the Characters Studio lists them: project-scoped records of
  /// the character type that have not been deleted.
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

  WorldBoardBranch _branch(WorldBoardSection section, List<String> titles) =>
      WorldBoardBranch(
        section: section,
        count: titles.length,
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

  String _manuscriptCaption(ManuscriptProjectSummary manuscript) {
    if (manuscript.chapterCount == 0) return '';
    final chapters =
        '${manuscript.chapterCount} chapter${manuscript.chapterCount == 1 ? '' : 's'}';
    final scenes =
        '${manuscript.sceneCount} scene${manuscript.sceneCount == 1 ? '' : 's'}';
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
