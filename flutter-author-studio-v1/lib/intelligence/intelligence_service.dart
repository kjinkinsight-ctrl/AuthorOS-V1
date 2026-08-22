/// AuthorOS Intelligence Layer — the aggregation layer.
///
/// This service owns no storage. It reads the project once, hands that one
/// reading to a set of pure detectors, and folds their findings into a report.
/// It creates no record, no link, no version and no audit event — the same
/// contract `AnalyticsService` and `WorldBoardService` hold, and pinned here by
/// `test/intelligence_read_only_test.dart`.
///
/// It is an aggregator, not a new engine. Where AuthorOS already decides
/// something — what "resolved" means, what counts as a mention, when two events
/// conflict — this asks the code that already decides it. The one thing the
/// application genuinely lacked was anyone asking those questions about the
/// whole project at once; every existing continuity check answers for a single
/// record, inside that record's own panel.
///
/// **Inherited read side effect.** `getSummary()`-style manuscript loading
/// seeds and saves a starter manuscript on a project whose manuscript has never
/// been opened, which writes chapter and scene nodes — a read that writes
/// (risk R-21). This service does not add a third such path: it calls
/// [AnalyticsService.loadManuscript], the same entry the World Board already
/// uses. Removing the side effect belongs to Story Graph Phase 0.
///
/// **Canon only.** Branch overlays (`branch_record_overlay_rows`) are not
/// resolved here, so the report describes canon. Branch-aware analysis is
/// deferred rather than half-done.
library;

import '../analytics_service.dart';
import '../core/built_in_record_types.dart';
import '../core/connected_domain.dart';
import '../core/record_types.dart';
import '../manuscript_store.dart';
import '../onboarding.dart';
import '../persistence/authoros_database.dart';
import 'detectors.dart';
import 'intelligence_models.dart';
import 'project_survey.dart';

class IntelligenceService {
  const IntelligenceService({
    required this.project,
    DriftConnectedDomainRepository? repository,
    this.manuscriptStore = const ManuscriptStore(),
    AnalyticsService? analytics,
  })  : _repository = repository,
        _analytics = analytics;

  /// The project the shell currently has open.
  final StarterProject project;

  final DriftConnectedDomainRepository? _repository;
  final AnalyticsService? _analytics;

  final ManuscriptStore manuscriptStore;

  DriftConnectedDomainRepository get repository =>
      _repository ?? authorOsRepository;

  /// Reused rather than re-implemented: the manuscript is the Manuscript
  /// Studio's to define, and Analytics already owns the one routine that loads
  /// it consistently for every screen.
  AnalyticsService get analytics =>
      _analytics ??
      AnalyticsService(
        project: project,
        repository: repository,
        manuscriptStore: manuscriptStore,
      );

  /// Reads the project and reports what is structurally wrong with it.
  ///
  /// Four reads, whatever the project's size and however many detectors exist:
  /// the manuscript, the project's records, the project's links, and any record
  /// types the project defines for itself. Everything after that is in memory.
  Future<IntelligenceReport> analyze({
    ManuscriptProjectSummary? manuscript,
  }) async {
    final survey = await surveyProject(manuscript: manuscript);
    return report(survey);
  }

  /// The one reading of the project every detector runs over.
  ///
  /// Public so a test can inspect the inputs a report was built from, and so a
  /// caller that already holds a survey can run detectors without reading again.
  /// [manuscript] lets a caller that has already loaded it — the World Board
  /// does, for its chapter titles — hand it over instead of paying for a
  /// second read of the same prose.
  Future<ProjectSurvey> surveyProject({
    ManuscriptProjectSummary? manuscript,
  }) async {
    final loaded = manuscript ?? await analytics.loadManuscript();
    final records = await repository.recordsByProject(project.id);
    final links = await repository.linksByScope(project.id);
    final customTypes = await repository.recordTypeDefinitionsByScope(
      scopeType: RecordScopeType.project,
      scopeId: project.id,
    );

    return ProjectSurvey.from(
      projectId: project.id,
      projectTitle: project.title,
      manuscript: loaded,
      records: records,
      links: links,
      typeDefinitions: <RecordTypeDefinition>[
        ...BuiltInRecordTypes.definitions,
        ...customTypes,
      ],
    );
  }

  /// Folds a survey into a report. Pure — no I/O, so a test can drive it with
  /// a hand-built survey.
  static IntelligenceReport report(ProjectSurvey survey) {
    final worldEntities = survey.worldEntities;
    final unused = unusedWorldEntities(survey);

    return IntelligenceReport(
      projectId: survey.projectId,
      projectTitle: survey.projectTitle,
      findings: detectAll(survey),
      connectedWorldEntities: worldEntities.length - unused.length,
      totalWorldEntities: worldEntities.length,
      hasManuscript: survey.hasManuscript,
    );
  }
}
