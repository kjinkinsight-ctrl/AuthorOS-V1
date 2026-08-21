/// Analytics Studio — the derivation layer.
///
/// This service owns no storage and no models of its own. It asks the Studios
/// that already own each domain — manuscript, characters, plot, timeline,
/// research — for what they hold, and folds the answers into one immutable
/// [AnalyticsSummary]. Every number it reports has to come back from one of
/// those services; nothing here invents a record, a count, or a second
/// definition of "what a chapter is".
///
/// Analytics is reproducible from source data: nothing calculated here is
/// persisted, and calculating never mutates a source record.
library;

import 'character_service.dart';
import 'core/connected_domain.dart';
import 'manuscript_store.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';
import 'plot_service.dart';
import 'timeline_service.dart';

/// A chapter highlighted by the analytics (longest or shortest).
class AnalyticsChapterStat {
  const AnalyticsChapterStat({required this.title, required this.wordCount});

  final String title;
  final int wordCount;
}

/// Stable, presentation-independent analytics for one project.
///
/// The summary stores only source-derived values; ratios are computed from
/// those values so repeated reads can never disagree with each other. Optional
/// data stays optional: when no writing target exists the target-relative
/// getters return `null` rather than a misleading `0%`.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.projectId,
    required this.projectName,
    required this.manuscriptStatus,
    required this.totalWordCount,
    required this.chapterCount,
    required this.sceneCount,
    required this.characterCount,
    required this.timelineEventCount,
    required this.plotRecordCount,
    required this.researchItemCount,
    required this.targetWordCount,
    required this.chaptersByStatus,
    required this.longestChapter,
    required this.shortestChapter,
    required this.charactersWithProfiles,
    required this.charactersWithRelationships,
    required this.charactersReferencedInManuscript,
    required this.activePlotThreadCount,
    required this.completedPlotThreadCount,
  });

  /// An empty project: every count zero, every optional value absent.
  factory AnalyticsSummary.empty({
    required String projectId,
    required String projectName,
    int targetWordCount = 0,
  }) =>
      AnalyticsSummary(
        projectId: projectId,
        projectName: projectName,
        manuscriptStatus: 'Not started',
        totalWordCount: 0,
        chapterCount: 0,
        sceneCount: 0,
        characterCount: 0,
        timelineEventCount: 0,
        plotRecordCount: 0,
        researchItemCount: 0,
        targetWordCount: targetWordCount,
        chaptersByStatus: const {},
        longestChapter: null,
        shortestChapter: null,
        charactersWithProfiles: 0,
        charactersWithRelationships: 0,
        charactersReferencedInManuscript: 0,
        activePlotThreadCount: 0,
        completedPlotThreadCount: 0,
      );

  // Project overview.
  final String projectId;
  final String projectName;

  /// Derived manuscript status label: `Not started`, `Drafting`, `Revising`,
  /// or `Complete`. Derived from chapter statuses, never stored.
  final String manuscriptStatus;

  final int totalWordCount;
  final int chapterCount;
  final int sceneCount;
  final int characterCount;
  final int timelineEventCount;
  final int plotRecordCount;
  final int researchItemCount;

  // Writing progress.

  /// The project's writing goal in words. `0` means no target was set.
  final int targetWordCount;

  /// Whether the author set a writing target. Consumers must not render a
  /// percentage when this is false.
  bool get hasWritingTarget => targetWordCount > 0;

  /// Progress toward the target in `0.0..1.0`, or `null` without a target.
  double? get progressTowardTarget => hasWritingTarget
      ? (totalWordCount / targetWordCount).clamp(0.0, 1.0)
      : null;

  /// Progress toward the target in `0..100`, or `null` without a target.
  double? get percentTowardTarget {
    final progress = progressTowardTarget;
    return progress == null ? null : progress * 100;
  }

  /// Words left before the target is reached, or `null` without a target.
  /// Never negative: overshooting the goal leaves zero words remaining.
  int? get wordsRemaining => hasWritingTarget
      ? (targetWordCount - totalWordCount).clamp(0, targetWordCount)
      : null;

  /// Whole words per chapter, `0` when the manuscript has no chapters.
  int get averageWordsPerChapter =>
      chapterCount == 0 ? 0 : totalWordCount ~/ chapterCount;

  /// Whole words per scene, `0` when the manuscript has no scenes.
  int get averageWordsPerScene =>
      sceneCount == 0 ? 0 : totalWordCount ~/ sceneCount;

  final AnalyticsChapterStat? longestChapter;
  final AnalyticsChapterStat? shortestChapter;

  // Chapter analytics.

  /// Chapter counts keyed by [ManuscriptNodeStatus.id]
  /// (`planned`, `draft`, `revising`, `complete`).
  final Map<String, int> chaptersByStatus;

  int get completedChapterCount =>
      chaptersByStatus[ManuscriptNodeStatus.complete.id] ?? 0;

  int get draftChapterCount =>
      chaptersByStatus[ManuscriptNodeStatus.draft.id] ?? 0;

  /// Alias for [averageWordsPerChapter], the chapter panel's vocabulary.
  int get averageChapterLength => averageWordsPerChapter;

  // Character analytics.

  /// Characters with at least one profile field filled in beyond the
  /// identity fields every character record is created with.
  final int charactersWithProfiles;

  /// Characters with at least one relationship connection to another record.
  final int charactersWithRelationships;

  /// Characters whose name appears in the manuscript's scene content.
  final int charactersReferencedInManuscript;

  // Story analytics.

  /// Plot records that are being actively worked (not resolved or abandoned).
  final int activePlotThreadCount;

  /// Plot records marked resolved or completed.
  final int completedPlotThreadCount;

  /// Overall completion toward the writing target; `null` without a target.
  double? get completionPercent => percentTowardTarget;
}

/// Derives [AnalyticsSummary] from the existing AuthorOS services.
///
/// Mirrors [WorldBoardService]'s shape so the two aggregation layers stay
/// interchangeable: the project comes from the shell, the repository defaults
/// to the app-wide [authorOsRepository], and the manuscript is read through
/// the Manuscript Studio's own store.
class AnalyticsService {
  const AnalyticsService({
    required this.project,
    DriftConnectedDomainRepository? repository,
    this.manuscriptStore = const ManuscriptStore(),
  }) : _repository = repository;

  /// The project the shell currently has open.
  final StarterProject project;

  final DriftConnectedDomainRepository? _repository;

  /// Reused rather than re-implemented: word, chapter, and scene counts are
  /// the Manuscript Studio's to define.
  final ManuscriptStore manuscriptStore;

  DriftConnectedDomainRepository get repository =>
      _repository ?? authorOsRepository;

  /// The character record type, as the Characters Studio defines it.
  static const characterTypeId = 'character';

  /// Research lives in the record system under two type ids: the built-in
  /// `research-entry` type and its selectable `research` alias. Both resolve
  /// to the Codex `research` category, so counting both matches the Codex.
  static const researchTypeIds = ['research-entry', 'research'];

  CharacterService get characters =>
      CharacterService(projectId: project.id, repository: repository);

  TimelineService get timeline =>
      TimelineService(projectId: project.id, repository: repository);

  PlotService get plot =>
      PlotService(projectId: project.id, repository: repository);

  /// Loads every source once and folds it into one summary.
  ///
  /// The record queries run in turn: they share one database connection, and
  /// a dashboard that opens in a few milliseconds does not need to race them.
  /// The manuscript is read separately because it does not live in the record
  /// repository.
  Future<AnalyticsSummary> getSummary() async {
    final manuscript = await loadManuscript();

    final characterRecords = await _activeCharacters();
    final timelineRecords = _active(await timeline.query.all());
    final plotRecords = _active(await plot.query.all());
    final researchRecords = await _activeResearch();

    final chapters = manuscript.chapters;
    final chaptersByStatus = <String, int>{};
    for (final chapter in chapters) {
      chaptersByStatus.update(
        chapter.status.id,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    ManuscriptChapter? longest;
    ManuscriptChapter? shortest;
    for (final chapter in chapters) {
      if (longest == null || chapter.wordCount > longest.wordCount) {
        longest = chapter;
      }
      if (shortest == null || chapter.wordCount < shortest.wordCount) {
        shortest = chapter;
      }
    }

    final charactersWithRelationships =
        await _countCharactersWithRelationships(characterRecords);

    return AnalyticsSummary(
      projectId: project.id,
      projectName: project.title,
      manuscriptStatus: _manuscriptStatus(manuscript),
      totalWordCount: manuscript.wordCount,
      chapterCount: manuscript.chapterCount,
      sceneCount: manuscript.sceneCount,
      characterCount: characterRecords.length,
      timelineEventCount: timelineRecords.length,
      plotRecordCount: plotRecords.length,
      researchItemCount: researchRecords.length,
      targetWordCount: project.wordGoal < 0 ? 0 : project.wordGoal,
      chaptersByStatus: Map.unmodifiable(chaptersByStatus),
      longestChapter: longest == null
          ? null
          : AnalyticsChapterStat(
              title: longest.title,
              wordCount: longest.wordCount,
            ),
      shortestChapter: shortest == null
          ? null
          : AnalyticsChapterStat(
              title: shortest.title,
              wordCount: shortest.wordCount,
            ),
      charactersWithProfiles: characterRecords
          .where(_hasProfileBeyondIdentity)
          .length,
      charactersWithRelationships: charactersWithRelationships,
      charactersReferencedInManuscript:
          _countCharactersReferenced(characterRecords, manuscript),
      activePlotThreadCount:
          plotRecords.where(_isActivePlotThread).length,
      completedPlotThreadCount:
          plotRecords.where(_isCompletedPlotThread).length,
    );
  }

  /// Reads the manuscript through the Manuscript Studio's own store, seeded
  /// exactly the way the Statistics Studio seeds it, so every screen reports
  /// the same word count for the same project.
  ///
  /// Public because the World Board needs the same manuscript to name its
  /// chapters, and a second seeding routine over there would be a second way
  /// for a project to have chapters. It reads; it never writes.
  Future<ManuscriptProjectSummary> loadManuscript() async {
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

  /// Characters as the Characters Studio lists them: project-scoped records
  /// of the character type that have not been deleted.
  Future<List<AuthorRecord>> _activeCharacters() async {
    final records = await repository.recordsByTypeAndScope(
      typeId: characterTypeId,
      scopeId: project.id,
    );
    return _active(records);
  }

  Future<List<AuthorRecord>> _activeResearch() async {
    final records = <AuthorRecord>[];
    for (final typeId in researchTypeIds) {
      records.addAll(
        await repository.recordsByTypeAndScope(
          typeId: typeId,
          scopeId: project.id,
        ),
      );
    }
    return _active(records);
  }

  Future<int> _countCharactersWithRelationships(
    List<AuthorRecord> characterRecords,
  ) async {
    var count = 0;
    for (final record in characterRecords) {
      final relationships =
          await characters.getCharacterRelationships(record.id);
      if (relationships.isNotEmpty) count++;
    }
    return count;
  }

  /// The manuscript status label the dashboard shows. A manuscript with no
  /// chapters and no words has not been started; one whose chapters are all
  /// complete is complete; revision anywhere outranks drafting.
  String _manuscriptStatus(ManuscriptProjectSummary manuscript) {
    final chapters = manuscript.chapters;
    if (chapters.isEmpty && manuscript.wordCount == 0) return 'Not started';
    if (chapters.isNotEmpty &&
        chapters.every(
          (chapter) => chapter.status == ManuscriptNodeStatus.complete,
        )) {
      return 'Complete';
    }
    if (chapters.any(
      (chapter) => chapter.status == ManuscriptNodeStatus.revising,
    )) {
      return 'Revising';
    }
    return 'Drafting';
  }

  /// Whether a character record carries profile data beyond the identity
  /// fields [CharacterService.createCharacter] seeds on every record.
  bool _hasProfileBeyondIdentity(AuthorRecord record) {
    for (final entry in record.fields.entries) {
      if (entry.key == 'identity.displayName' ||
          entry.key == 'identity.fullName') {
        continue;
      }
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      if (value is Iterable && value.isEmpty) continue;
      if (value is Map && value.isEmpty) continue;
      return true;
    }
    return false;
  }

  int _countCharactersReferenced(
    List<AuthorRecord> characterRecords,
    ManuscriptProjectSummary manuscript,
  ) {
    if (characterRecords.isEmpty) return 0;
    final buffer = StringBuffer();
    for (final chapter in manuscript.chapters) {
      for (final scene in chapter.scenes) {
        buffer
          ..write(scene.content)
          ..write('\n');
      }
    }
    final content = buffer.toString().toLowerCase();
    if (content.trim().isEmpty) return 0;
    var count = 0;
    for (final record in characterRecords) {
      final name = record.title.trim().toLowerCase();
      if (name.isEmpty) continue;
      if (content.contains(name)) count++;
    }
    return count;
  }

  /// Mirrors the Plot Studio's own status semantics: `plotStatus` defaults to
  /// `planned`, and a thread is active while its record is active and it has
  /// not been resolved, completed, or abandoned.
  String _plotStatus(AuthorRecord record) =>
      '${record.fields['plotStatus'] ?? ''}'.trim().toLowerCase();

  bool _isCompletedPlotThread(AuthorRecord record) {
    final status = _plotStatus(record);
    return status == 'resolved' || status == 'completed';
  }

  bool _isActivePlotThread(AuthorRecord record) {
    final status = _plotStatus(record);
    return record.status == AuthorRecordStatus.active &&
        status != 'resolved' &&
        status != 'completed' &&
        status != 'abandoned';
  }

  List<AuthorRecord> _active(List<AuthorRecord> records) => records
      .where((record) => record.status != AuthorRecordStatus.deleted)
      .toList();
}
