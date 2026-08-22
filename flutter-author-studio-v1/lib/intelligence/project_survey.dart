/// AuthorOS Intelligence Layer — the one read of the project.
///
/// Every detector runs over this object and none of them touches a database.
/// That is deliberate on two counts: the whole analysis costs a fixed four
/// queries no matter how many conditions are added, and a detector becomes a
/// pure function that a test can exercise without a repository at all.
///
/// The survey is a *read*. It creates nothing, updates nothing and deletes
/// nothing — mirroring the contract `AnalyticsService` and `WorldBoardService`
/// already hold, and pinned by `test/intelligence_read_only_test.dart`.
library;

import '../core/connected_domain.dart';
import '../core/record_types.dart';
import '../manuscript_store.dart';

/// The record categories that count as worldbuilding.
///
/// Selecting by category rather than by a hardcoded list of type ids means an
/// author's own custom types are included automatically: a custom type
/// declares the category it belongs to, and derived types inherit their
/// parent's when they do not override it.
///
/// `maps` and `routes` are excluded on purpose. A map marker with no
/// manuscript connection is a normal map marker, not a finding.
const worldbuildingCategoryIds = <String>{
  'world',
  'locations',
  'factions',
  'culture',
  'religion',
  'magic',
  'history',
  'items',
  'lore',
  'creatures',
  'technology',
};

/// The category every character record type belongs to.
const characterCategoryId = 'characters';

/// The connection types that mean "this record reaches the manuscript".
const manuscriptConnectionTypeIds = <String>{'appearsIn', 'mentionedIn'};

/// One project, read once, indexed for analysis.
class ProjectSurvey {
  ProjectSurvey({
    required this.projectId,
    required this.projectTitle,
    required this.manuscript,
    required List<AuthorRecord> records,
    required List<RecordLink> links,
    required Map<String, String> categoryByTypeId,
  })  : records = List.unmodifiable(
          records.where(
            (record) => record.status == AuthorRecordStatus.active,
          ),
        ),
        links = List.unmodifiable(links),
        _categoryByTypeId = categoryByTypeId {
    for (final record in this.records) {
      _recordsById[record.id] = record;
      (_recordsByCategory[categoryFor(record.typeId)] ??= []).add(record);
    }
    for (final link in this.links) {
      (_linksByEntity[link.sourceId] ??= []).add(link);
      (_linksByEntity[link.targetId] ??= []).add(link);
    }
    for (final chapter in manuscript.chapters) {
      _chapterNodeIds.add(chapter.id);
      for (final scene in chapter.scenes) {
        _sceneNodeIds.add(scene.id);
        _scenes.add(scene);
        _chapterOfScene[scene.id] = chapter;
      }
    }
  }

  /// Builds a survey from the parts the service has already loaded.
  ///
  /// [typeDefinitions] should be the built-in definitions plus any the project
  /// itself defines, so custom record types resolve to a real category rather
  /// than falling through to [unknownCategoryId].
  factory ProjectSurvey.from({
    required String projectId,
    required String projectTitle,
    required ManuscriptProjectSummary manuscript,
    required List<AuthorRecord> records,
    required List<RecordLink> links,
    required Iterable<RecordTypeDefinition> typeDefinitions,
  }) =>
      ProjectSurvey(
        projectId: projectId,
        projectTitle: projectTitle,
        manuscript: manuscript,
        records: records,
        links: links,
        categoryByTypeId: {
          for (final definition in typeDefinitions)
            definition.id: definition.categoryId,
        },
      );

  /// The category reported for a type this project has no definition for.
  static const unknownCategoryId = '';

  final String projectId;
  final String projectTitle;
  final ManuscriptProjectSummary manuscript;

  /// Active records only. Deletion in AuthorOS is soft — a deleted record keeps
  /// its row and every edge stays traversable (risk R-10) — so a survey that
  /// forgot this filter would report findings about records the author has
  /// already thrown away.
  final List<AuthorRecord> records;

  final List<RecordLink> links;

  final Map<String, String> _categoryByTypeId;
  final Map<String, AuthorRecord> _recordsById = {};
  final Map<String, List<AuthorRecord>> _recordsByCategory = {};
  final Map<String, List<RecordLink>> _linksByEntity = {};
  final Set<String> _chapterNodeIds = {};
  final Set<String> _sceneNodeIds = {};
  final List<ManuscriptScene> _scenes = [];
  final Map<String, ManuscriptChapter> _chapterOfScene = {};

  /// Every scene in the manuscript, chapter order then scene order.
  List<ManuscriptScene> get scenes => List.unmodifiable(_scenes);

  /// The chapter a scene belongs to.
  ManuscriptChapter? chapterOfScene(String sceneId) =>
      _chapterOfScene[sceneId];

  /// The manuscript nodes that actually exist.
  ///
  /// Derived from the loaded manuscript, **never** from `manuscript_node_rows`.
  /// Deleting a scene today leaves its node row, its links and its search-index
  /// entry behind permanently (risk R-1, still open until Story Graph Phase 0).
  /// Building the live set from the prose the author can still see means a
  /// ghost node cannot become a finding.
  Set<String> get liveManuscriptNodeIds => {..._chapterNodeIds, ..._sceneNodeIds};

  Set<String> get sceneNodeIds => Set.unmodifiable(_sceneNodeIds);
  Set<String> get chapterNodeIds => Set.unmodifiable(_chapterNodeIds);

  /// True once the author has written anything at all.
  ///
  /// Several conditions cannot be judged without prose, and a project on its
  /// first day should not open to a list of findings whose only real content
  /// is "you have not started yet".
  bool get hasManuscript =>
      _scenes.any((scene) => scene.content.trim().isNotEmpty);

  AuthorRecord? recordById(String id) => _recordsById[id];

  bool isLiveManuscriptNode(String id) =>
      _sceneNodeIds.contains(id) || _chapterNodeIds.contains(id);

  /// The category a record type belongs to, or [unknownCategoryId].
  String categoryFor(String typeId) =>
      _categoryByTypeId[typeId] ?? unknownCategoryId;

  /// Active records in any of [categoryIds], title-ordered.
  List<AuthorRecord> recordsInCategories(Set<String> categoryIds) => [
        for (final categoryId in categoryIds)
          ...?_recordsByCategory[categoryId],
      ]..sort((left, right) => left.title.compareTo(right.title));

  /// Active records of any of [typeIds], title-ordered.
  List<AuthorRecord> recordsOfTypes(Set<String> typeIds) => [
        for (final record in records)
          if (typeIds.contains(record.typeId)) record,
      ]..sort((left, right) => left.title.compareTo(right.title));

  /// Every character record, however it was typed.
  ///
  /// Character templates (`character-main`, `character-villain`, …) all declare
  /// the `characters` category, so selecting by category catches a record
  /// saved under a template as well as one saved under the base type.
  List<AuthorRecord> get characters =>
      recordsInCategories(const {characterCategoryId});

  /// Every worldbuilding record.
  List<AuthorRecord> get worldEntities =>
      recordsInCategories(worldbuildingCategoryIds);

  /// Links touching [entityId] in either direction.
  List<RecordLink> linksOf(String entityId) =>
      List.unmodifiable(_linksByEntity[entityId] ?? const []);

  /// The other endpoint of every link touching [entityId].
  Set<String> connectedIds(String entityId) => {
        for (final link in linksOf(entityId))
          link.sourceId == entityId ? link.targetId : link.sourceId,
      };

  /// Whether [entityId] reaches a live scene or chapter through any link.
  ///
  /// [typeIds] narrows the check to particular connection types; omit it to
  /// accept any connection at all.
  bool reachesManuscript(String entityId, {Set<String>? typeIds}) {
    for (final link in linksOf(entityId)) {
      if (typeIds != null && !typeIds.contains(link.typeId)) continue;
      final other = link.sourceId == entityId ? link.targetId : link.sourceId;
      if (isLiveManuscriptNode(other)) return true;
    }
    return false;
  }

  /// The prose of one scene, lowercased, as the continuity engines read it:
  /// title, body, notes and time label together.
  String proseOfScene(ManuscriptScene scene) => [
        scene.title,
        scene.content,
        scene.notes,
        scene.timeLabel,
      ].join('\n').toLowerCase();

  /// Every scene's prose, concatenated — for "is this name anywhere in the
  /// book at all?" questions that do not care which scene.
  late final String allProse =
      _scenes.map(proseOfScene).join('\n');
}
