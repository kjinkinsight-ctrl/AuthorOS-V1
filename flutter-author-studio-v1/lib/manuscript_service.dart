import 'core/branch_domain.dart';
import 'core/branch_service.dart';
import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/connection_types.dart';
import 'core/record_inspection.dart';
import 'core/record_inspector.dart';
import 'core/record_service.dart';
import 'core/record_validation.dart';
import 'core/safe_delete.dart';
import 'core/safe_delete_service.dart';
import 'core/search_models.dart';
import 'core/universal_search.dart';
import 'core/version_audit.dart';
import 'core/version_audit_service.dart';
import 'continuity.dart';
import 'continuity_actions.dart';
import 'manuscript_continuity.dart';
import 'manuscript_store.dart';
import 'persistence/authoros_database.dart';
import 'timeline_domain.dart';
import 'timeline_service.dart';

/// Which manuscript node a Phase 2 operation addresses.
enum ManuscriptNodeKind { manuscript, chapter, scene }

extension ManuscriptNodeKindX on ManuscriptNodeKind {
  /// The Universal Record type id used for this node in the shared store.
  String get typeId => switch (this) {
        ManuscriptNodeKind.manuscript => 'book',
        ManuscriptNodeKind.chapter => 'chapter',
        ManuscriptNodeKind.scene => 'scene',
      };

  String get label => switch (this) {
        ManuscriptNodeKind.manuscript => 'Manuscript',
        ManuscriptNodeKind.chapter => 'Chapter',
        ManuscriptNodeKind.scene => 'Scene',
      };
}

/// Raised when a mutation would change Canon while a branch is active, or
/// would otherwise break the manuscript's connected guarantees.
class ManuscriptCanonException implements Exception {
  const ManuscriptCanonException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One problem found by [ManuscriptService.validateManuscript].
class ManuscriptValidationIssue {
  const ManuscriptValidationIssue({
    required this.code,
    required this.message,
    this.nodeId,
    this.nodeKind = ManuscriptNodeKind.scene,
    this.isError = false,
  });

  final String code;
  final String message;
  final String? nodeId;
  final ManuscriptNodeKind nodeKind;
  final bool isError;
}

/// Word counts and writing progress for the manuscript, one chapter, or one
/// scene. Derived from the manuscript store, which stays the single home of
/// manuscript body text.
class ManuscriptProgress {
  const ManuscriptProgress({
    required this.wordCount,
    required this.goalWords,
    required this.chapterCount,
    required this.sceneCount,
    required this.statusCounts,
    required this.wordsWrittenToday,
  });

  final int wordCount;
  final int goalWords;
  final int chapterCount;
  final int sceneCount;
  final Map<ManuscriptNodeStatus, int> statusCounts;
  final int wordsWrittenToday;

  double get goalProgress =>
      goalWords <= 0 ? 0 : (wordCount / goalWords).clamp(0.0, 1.0);

  int get completedScenes => statusCounts[ManuscriptNodeStatus.complete] ?? 0;

  double get completionRatio =>
      sceneCount == 0 ? 0 : completedScenes / sceneCount;

  int get remainingWords =>
      goalWords <= wordCount ? 0 : goalWords - wordCount;
}

/// A record in another Studio that is connected to a manuscript node.
class ManuscriptConnection {
  const ManuscriptConnection({
    required this.link,
    required this.nodeId,
    required this.recordId,
    required this.recordType,
    required this.title,
    required this.destination,
    required this.incoming,
    required this.displayName,
    required this.exists,
  });

  final RecordLink link;
  final String nodeId;
  final String recordId;
  final String recordType;
  final String title;
  final SearchDestination destination;
  final bool incoming;
  final String displayName;
  final bool exists;

  String get linkId => link.id;

  String get connectionTypeId => link.typeId;
}

/// Search and filter criteria for the manuscript navigator.
///
/// Filtering runs over the manuscript the store already loaded, and full-text
/// queries are answered by the shared universal search index, so Phase 2 adds
/// no second index.
class ManuscriptFilter {
  const ManuscriptFilter({
    this.query = '',
    this.statuses = const {},
    this.chapterIds = const {},
    this.pov = '',
    this.location = '',
    this.connectedRecordId = '',
    this.onlyUnconnected = false,
    this.onlyEmpty = false,
  });

  final String query;
  final Set<ManuscriptNodeStatus> statuses;
  final Set<String> chapterIds;
  final String pov;
  final String location;
  final String connectedRecordId;
  final bool onlyUnconnected;
  final bool onlyEmpty;

  bool get isEmpty =>
      query.trim().isEmpty &&
      statuses.isEmpty &&
      chapterIds.isEmpty &&
      pov.trim().isEmpty &&
      location.trim().isEmpty &&
      connectedRecordId.trim().isEmpty &&
      !onlyUnconnected &&
      !onlyEmpty;

  ManuscriptFilter copyWith({
    String? query,
    Set<ManuscriptNodeStatus>? statuses,
    Set<String>? chapterIds,
    String? pov,
    String? location,
    String? connectedRecordId,
    bool? onlyUnconnected,
    bool? onlyEmpty,
  }) =>
      ManuscriptFilter(
        query: query ?? this.query,
        statuses: statuses ?? this.statuses,
        chapterIds: chapterIds ?? this.chapterIds,
        pov: pov ?? this.pov,
        location: location ?? this.location,
        connectedRecordId: connectedRecordId ?? this.connectedRecordId,
        onlyUnconnected: onlyUnconnected ?? this.onlyUnconnected,
        onlyEmpty: onlyEmpty ?? this.onlyEmpty,
      );
}

/// One scene matched by [ManuscriptService.filterScenes].
class ManuscriptSceneMatch {
  const ManuscriptSceneMatch({
    required this.chapter,
    required this.scene,
    this.snippet = '',
  });

  final ManuscriptChapter chapter;
  final ManuscriptScene scene;
  final String snippet;
}

/// The Inspector view of a chapter or scene node.
///
/// Manuscript nodes are entities in the connected store but are not
/// [AuthorRecord]s, so [UniversalRecordInspector] cannot own them. This
/// composes the same inspection value types the record Inspector uses, from
/// the same shared services, rather than defining a parallel model.
class ManuscriptNodeInspection {
  const ManuscriptNodeInspection({
    required this.nodeId,
    required this.nodeKind,
    required this.title,
    required this.projectId,
    required this.createdAt,
    required this.updatedAt,
    required this.wordCount,
    required this.status,
    required this.outgoingConnections,
    required this.incomingConnections,
    required this.references,
    required this.history,
    required this.scope,
    required this.validation,
    required this.safeDelete,
    required this.capabilities,
    this.branchId,
  });

  final String nodeId;
  final ManuscriptNodeKind nodeKind;
  final String title;
  final String projectId;
  final String? branchId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int wordCount;
  final ManuscriptNodeStatus status;
  final List<ConnectionInspection> outgoingConnections;
  final List<ConnectionInspection> incomingConnections;
  final List<ReferenceInspection> references;
  final HistoryInspection history;
  final ScopeInspection scope;
  final ValidationInspection validation;
  final SafeDeleteInspection safeDelete;
  final InspectionCapabilities capabilities;
}

/// Manuscript Studio Phase 2.
///
/// Every mutation goes through the shared services that already exist:
/// [ManuscriptStore] keeps manuscript body text, [ConnectionEngine] keeps
/// relationships, [VersionAuditService] keeps history, [UniversalSearchService]
/// answers queries and [BranchService] guards Canon. This class adds no
/// database, index, history store or second manuscript record model.
class ManuscriptService {
  const ManuscriptService({
    required this.projectId,
    required this.repository,
    this.store = const ManuscriptStore(),
    this.activeBranchId,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;
  final ManuscriptStore store;

  /// When set, Canon is read-only: the manuscript belongs to Canon and a
  /// branch author must leave the branch before editing it.
  final String? activeBranchId;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);
  ConnectionEngine get connections =>
      ConnectionEngine(scopeId: projectId, repository: repository);
  BranchService get branches =>
      BranchService(projectId: projectId, repository: repository);
  UniversalSearchService get search =>
      UniversalSearchService(projectId: projectId, repository: repository);
  VersionAuditService get history =>
      VersionAuditService(projectId: projectId, repository: repository);
  UniversalRecordInspector get inspector =>
      UniversalRecordInspector(projectId: projectId, repository: repository);
  SafeDeleteService get safeDelete =>
      SafeDeleteService(projectId: projectId, repository: repository);

  ManuscriptService forBranch(String? branchId) => ManuscriptService(
        projectId: projectId,
        repository: repository,
        store: store,
        activeBranchId: branchId,
      );

  bool get canEditCanon => activeBranchId == null;

  // --- Loading and saving ------------------------------------------------

  Future<ManuscriptProjectSummary> load({
    required String manuscriptTitle,
    List<ManuscriptChapterSeed> defaultChapters = const [],
    String firstSceneTitle = 'Opening Scene',
  }) =>
      store.loadStudio(
        projectId,
        manuscriptTitle: manuscriptTitle,
        defaultChapters: defaultChapters,
        firstSceneTitle: firstSceneTitle,
      );

  /// Persists [manuscript] through the existing store and records one history
  /// entry per node the change touched.
  ///
  /// [changed] names the nodes whose version should advance; when it is empty
  /// no history is written, which is what an idle autosave should do.
  Future<ManuscriptProjectSummary> save(
    ManuscriptProjectSummary manuscript, {
    Iterable<String> changed = const [],
    AuditChangeType changeType = AuditChangeType.updated,
    String? summary,
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
    bool requireCanon = true,
  }) async {
    if (requireCanon) _requireCanonEditable();
    final now = (timestamp ?? DateTime.now()).toUtc();
    final normalized = manuscript
        .copyWith(chapters: _sequencedChapters(manuscript.chapters))
        .normalized()
        .copyWith(updatedAt: now);
    await store.saveStudio(normalized);
    for (final nodeId in changed.toSet()) {
      await _appendNodeHistory(
        normalized,
        nodeId,
        changeType: changeType,
        summary: summary,
        metadata: metadata,
        timestamp: now,
      );
    }
    return normalized;
  }

  Future<void> _appendNodeHistory(
    ManuscriptProjectSummary manuscript,
    String nodeId, {
    required AuditChangeType changeType,
    String? summary,
    Map<String, Object?> metadata = const {},
    required DateTime timestamp,
  }) async {
    final node = _nodeFor(manuscript, nodeId);
    if (node == null) return;
    final entry = await history.forManuscriptNode(
      node,
      changeType: changeType,
      summary: summary ?? '${changeType.name} ${node.title}',
      timestamp: timestamp,
      metadata: metadata,
    );
    await repository.appendHistory(entry.version, entry.audit);
  }

  ManuscriptNodeReference? _nodeFor(
    ManuscriptProjectSummary manuscript,
    String nodeId,
  ) {
    final chapter = manuscript.chapterById(nodeId);
    if (chapter != null) {
      return ManuscriptStore.manuscriptNodeForChapter(chapter, projectId);
    }
    final scene = manuscript.sceneById(nodeId);
    if (scene != null) {
      return ManuscriptStore.manuscriptNodeForScene(scene, projectId);
    }
    return null;
  }

  /// Writes one deleted node's final history entry, so a removed chapter or
  /// scene still leaves an audit trail in the shared history system.
  Future<void> _appendDeletionHistory(
    ManuscriptNodeReference node, {
    required DateTime timestamp,
    Map<String, Object?> metadata = const {},
  }) async {
    final entry = await history.forManuscriptNode(
      node,
      changeType: AuditChangeType.deleted,
      summary: 'Deleted ${node.title}',
      timestamp: timestamp,
      metadata: metadata,
    );
    await repository.appendHistory(entry.version, entry.audit);
  }

  void _requireCanonEditable() {
    final branchId = activeBranchId;
    if (branchId != null) {
      throw ManuscriptCanonException(
        'The manuscript is Canon and cannot be edited while the $branchId '
        'branch is active. Leave the branch to keep writing.',
      );
    }
  }

  // --- Structure ---------------------------------------------------------

  Future<ManuscriptProjectSummary> createChapter(
    ManuscriptProjectSummary manuscript, {
    required String title,
    String firstSceneTitle = 'Scene 01',
    String? id,
    String? sceneId,
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('A chapter title is required.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final chapterId = id ?? ManuscriptId.create('chapter');
    await _requireFreeEntityId(chapterId);
    final newSceneId = sceneId ?? ManuscriptId.create('scene');
    await _requireFreeEntityId(newSceneId);
    final chapter = ManuscriptChapter(
      id: chapterId,
      title: trimmed,
      order: manuscript.chapters.length + 1,
      status: ManuscriptNodeStatus.planned,
      createdAt: now,
      updatedAt: now,
      scenes: [
        ManuscriptScene(
          id: newSceneId,
          chapterId: chapterId,
          title: firstSceneTitle.trim().isEmpty
              ? 'Scene 01'
              : firstSceneTitle.trim(),
          order: 1,
          content: '',
          status: ManuscriptNodeStatus.planned,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    return save(
      manuscript.copyWith(chapters: [...manuscript.chapters, chapter]),
      changed: [chapterId, newSceneId],
      changeType: AuditChangeType.created,
      timestamp: now,
    );
  }

  Future<ManuscriptProjectSummary> createScene(
    ManuscriptProjectSummary manuscript, {
    required String chapterId,
    required String title,
    String? id,
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final chapter = manuscript.chapterById(chapterId);
    if (chapter == null) {
      throw StateError('Unknown chapter: $chapterId');
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('A scene title is required.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final sceneId = id ?? ManuscriptId.create('scene');
    await _requireFreeEntityId(sceneId);
    final scene = ManuscriptScene(
      id: sceneId,
      chapterId: chapterId,
      title: trimmed,
      order: chapter.scenes.length + 1,
      content: '',
      status: ManuscriptNodeStatus.planned,
      createdAt: now,
      updatedAt: now,
    );
    return save(
      _withChapter(
        manuscript,
        chapter.copyWith(scenes: [...chapter.scenes, scene], updatedAt: now),
      ),
      changed: [sceneId, chapterId],
      changeType: AuditChangeType.created,
      timestamp: now,
    );
  }

  Future<ManuscriptProjectSummary> renameChapter(
    ManuscriptProjectSummary manuscript,
    String chapterId,
    String title, {
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final chapter = manuscript.chapterById(chapterId);
    if (chapter == null) throw StateError('Unknown chapter: $chapterId');
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError('A chapter title is required.');
    final now = (timestamp ?? DateTime.now()).toUtc();
    return save(
      _withChapter(
        manuscript,
        chapter.copyWith(title: trimmed, updatedAt: now),
      ),
      changed: [chapterId],
      changeType: AuditChangeType.renamed,
      metadata: {'previousTitle': chapter.title, 'newTitle': trimmed},
      timestamp: now,
    );
  }

  /// Files [chapterId] under [bookId], or releases it when [bookId] is null.
  ///
  /// Book membership is manuscript structure, so it is stored on the chapter
  /// and projected into its node's `extensionData` — the same shape a scene's
  /// `chapterId` already has. Deliberately not an edge: a chapter node is
  /// upsert-only and never deleted, so an edge here would survive the chapter
  /// it describes.
  Future<ManuscriptProjectSummary> assignChapterToBook(
    ManuscriptProjectSummary manuscript,
    String chapterId,
    String? bookId, {
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final chapter = manuscript.chapterById(chapterId);
    if (chapter == null) throw StateError('Unknown chapter: $chapterId');
    final target = bookId?.trim();
    final normalized = target == null || target.isEmpty ? null : target;
    if (normalized == chapter.bookId) return manuscript;
    final now = (timestamp ?? DateTime.now()).toUtc();
    return save(
      _withChapter(
        manuscript,
        chapter.copyWith(
          bookId: normalized,
          clearBookId: normalized == null,
          updatedAt: now,
        ),
      ),
      changed: [chapterId],
      metadata: {
        'previousBookId': chapter.bookId,
        'newBookId': normalized,
      },
      timestamp: now,
    );
  }

  /// The chapters filed under [bookId], in manuscript order.
  ///
  /// Passing null returns the chapters no book claims, which is every chapter
  /// in a project that has not been split into books.
  List<ManuscriptChapter> chaptersForBook(
    ManuscriptProjectSummary manuscript,
    String? bookId,
  ) {
    final target = bookId?.trim();
    final normalized = target == null || target.isEmpty ? null : target;
    return manuscript.chapters
        .where((chapter) => chapter.bookId == normalized)
        .toList();
  }

  /// The book a scene or chapter belongs to, or null when no book claims it.
  ///
  /// A scene inherits its chapter's book rather than storing its own, so the
  /// two can never disagree.
  String? bookForNode(ManuscriptProjectSummary manuscript, String nodeId) {
    final chapter = manuscript.chapterById(nodeId);
    if (chapter != null) return chapter.bookId;
    for (final each in manuscript.chapters) {
      if (each.scenes.any((scene) => scene.id == nodeId)) return each.bookId;
    }
    return null;
  }

  Future<ManuscriptProjectSummary> renameScene(
    ManuscriptProjectSummary manuscript,
    String sceneId,
    String title, {
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final scene = manuscript.sceneById(sceneId);
    if (scene == null) throw StateError('Unknown scene: $sceneId');
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError('A scene title is required.');
    final now = (timestamp ?? DateTime.now()).toUtc();
    return save(
      _withScene(manuscript, scene.copyWith(title: trimmed, updatedAt: now)),
      changed: [sceneId],
      changeType: AuditChangeType.renamed,
      metadata: {'previousTitle': scene.title, 'newTitle': trimmed},
      timestamp: now,
    );
  }

  Future<ManuscriptProjectSummary> setChapterStatus(
    ManuscriptProjectSummary manuscript,
    String chapterId,
    ManuscriptNodeStatus status, {
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final chapter = manuscript.chapterById(chapterId);
    if (chapter == null) throw StateError('Unknown chapter: $chapterId');
    final now = (timestamp ?? DateTime.now()).toUtc();
    return save(
      _withChapter(manuscript, chapter.copyWith(status: status, updatedAt: now)),
      changed: [chapterId],
      changeType: AuditChangeType.statusChanged,
      metadata: {
        'previousStatus': chapter.status.id,
        'newStatus': status.id,
      },
      timestamp: now,
    );
  }

  Future<ManuscriptProjectSummary> setSceneStatus(
    ManuscriptProjectSummary manuscript,
    String sceneId,
    ManuscriptNodeStatus status, {
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final scene = manuscript.sceneById(sceneId);
    if (scene == null) throw StateError('Unknown scene: $sceneId');
    final now = (timestamp ?? DateTime.now()).toUtc();
    return save(
      _withScene(manuscript, scene.copyWith(status: status, updatedAt: now)),
      changed: [sceneId],
      changeType: AuditChangeType.statusChanged,
      metadata: {'previousStatus': scene.status.id, 'newStatus': status.id},
      timestamp: now,
    );
  }

  /// Updates scene metadata without touching the scene body.
  Future<ManuscriptProjectSummary> updateSceneMetadata(
    ManuscriptProjectSummary manuscript,
    String sceneId, {
    String? title,
    String? pov,
    String? location,
    String? timeLabel,
    String? notes,
    ManuscriptNodeStatus? status,
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final scene = manuscript.sceneById(sceneId);
    if (scene == null) throw StateError('Unknown scene: $sceneId');
    final now = (timestamp ?? DateTime.now()).toUtc();
    final trimmedTitle = title?.trim();
    if (trimmedTitle != null && trimmedTitle.isEmpty) {
      throw ArgumentError('A scene title is required.');
    }
    return save(
      _withScene(
        manuscript,
        scene.copyWith(
          title: trimmedTitle,
          pov: pov,
          location: location,
          timeLabel: timeLabel,
          notes: notes,
          status: status,
          updatedAt: now,
        ),
      ),
      changed: [sceneId],
      timestamp: now,
    );
  }

  Future<ManuscriptProjectSummary> updateChapterMetadata(
    ManuscriptProjectSummary manuscript,
    String chapterId, {
    String? title,
    String? summary,
    String? prompt,
    String? pov,
    ManuscriptNodeStatus? status,
    List<String>? linkedChapterIds,
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final chapter = manuscript.chapterById(chapterId);
    if (chapter == null) throw StateError('Unknown chapter: $chapterId');
    final now = (timestamp ?? DateTime.now()).toUtc();
    if (linkedChapterIds != null) {
      for (final linkedId in linkedChapterIds) {
        if (linkedId == chapterId) {
          throw ArgumentError('A chapter cannot be linked to itself.');
        }
        if (manuscript.chapterById(linkedId) == null) {
          throw StateError('Unknown linked chapter: $linkedId');
        }
      }
    }
    final trimmedTitle = title?.trim();
    if (trimmedTitle != null && trimmedTitle.isEmpty) {
      throw ArgumentError('A chapter title is required.');
    }
    return save(
      _withChapter(
        manuscript,
        chapter.copyWith(
          title: trimmedTitle,
          summary: summary,
          prompt: prompt,
          pov: pov,
          status: status,
          linkedChapterIds: linkedChapterIds,
          updatedAt: now,
        ),
      ),
      changed: [chapterId],
      timestamp: now,
    );
  }

  /// Replaces one scene's body. Prose is written only to the manuscript store.
  Future<ManuscriptProjectSummary> writeSceneBody(
    ManuscriptProjectSummary manuscript,
    String sceneId,
    String content, {
    bool recordHistory = false,
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final scene = manuscript.sceneById(sceneId);
    if (scene == null) throw StateError('Unknown scene: $sceneId');
    final now = (timestamp ?? DateTime.now()).toUtc();
    final updated = scene.copyWith(content: content, updatedAt: now);
    return save(
      _withScene(manuscript, updated),
      changed: recordHistory ? [sceneId] : const [],
      metadata: {
        'previousWordCount': scene.wordCount,
        'newWordCount': updated.wordCount,
      },
      timestamp: now,
    );
  }

  // --- Ordering ----------------------------------------------------------

  Future<ManuscriptProjectSummary> moveChapter(
    ManuscriptProjectSummary manuscript,
    String chapterId,
    int delta, {
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final ordered = [...manuscript.chapters]
      ..sort((left, right) => left.order.compareTo(right.order));
    final index = ordered.indexWhere((chapter) => chapter.id == chapterId);
    if (index < 0) throw StateError('Unknown chapter: $chapterId');
    final target = index + delta;
    if (target < 0 || target >= ordered.length) return manuscript;
    final now = (timestamp ?? DateTime.now()).toUtc();
    final moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    return save(
      manuscript.copyWith(chapters: ordered),
      changed: [chapterId],
      metadata: {'previousOrder': index + 1, 'newOrder': target + 1},
      timestamp: now,
    );
  }

  Future<ManuscriptProjectSummary> moveScene(
    ManuscriptProjectSummary manuscript,
    String sceneId,
    int delta, {
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final chapter = manuscript.chapterOfScene(sceneId);
    if (chapter == null) throw StateError('Unknown scene: $sceneId');
    final ordered = [...chapter.scenes]
      ..sort((left, right) => left.order.compareTo(right.order));
    final index = ordered.indexWhere((scene) => scene.id == sceneId);
    final target = index + delta;
    if (target < 0 || target >= ordered.length) return manuscript;
    final now = (timestamp ?? DateTime.now()).toUtc();
    final moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    return save(
      _withChapter(
        manuscript,
        chapter.copyWith(scenes: ordered, updatedAt: now),
      ),
      changed: [sceneId],
      metadata: {'previousOrder': index + 1, 'newOrder': target + 1},
      timestamp: now,
    );
  }

  Future<ManuscriptProjectSummary> moveSceneToChapter(
    ManuscriptProjectSummary manuscript,
    String sceneId,
    String chapterId, {
    int? position,
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final source = manuscript.chapterOfScene(sceneId);
    final destination = manuscript.chapterById(chapterId);
    if (source == null) throw StateError('Unknown scene: $sceneId');
    if (destination == null) throw StateError('Unknown chapter: $chapterId');
    if (source.id == destination.id) return manuscript;
    final now = (timestamp ?? DateTime.now()).toUtc();
    final scene = manuscript.sceneById(sceneId)!;
    final remaining =
        source.scenes.where((item) => item.id != sceneId).toList();
    final target = [...destination.scenes];
    final insertAt = position == null
        ? target.length
        : position.clamp(0, target.length).toInt();
    target.insert(
      insertAt,
      scene.copyWith(chapterId: destination.id, updatedAt: now),
    );
    var next = _withChapter(
      manuscript,
      source.copyWith(scenes: remaining, updatedAt: now),
    );
    next = _withChapter(
      next,
      destination.copyWith(scenes: target, updatedAt: now),
    );
    return save(
      next,
      changed: [sceneId, source.id, destination.id],
      changeType: AuditChangeType.scopeChanged,
      metadata: {
        'previousChapterId': source.id,
        'newChapterId': destination.id,
      },
      timestamp: now,
    );
  }

  // --- Duplication and deletion -----------------------------------------

  Future<ManuscriptProjectSummary> duplicateScene(
    ManuscriptProjectSummary manuscript,
    String sceneId, {
    String? newId,
    String? title,
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final chapter = manuscript.chapterOfScene(sceneId);
    final scene = manuscript.sceneById(sceneId);
    if (chapter == null || scene == null) {
      throw StateError('Unknown scene: $sceneId');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final copyId = newId ?? ManuscriptId.create('scene');
    await _requireFreeEntityId(copyId);
    final ordered = [...chapter.scenes]
      ..sort((left, right) => left.order.compareTo(right.order));
    final index = ordered.indexWhere((item) => item.id == sceneId);
    ordered.insert(
      index + 1,
      scene.copyWith(
        id: copyId,
        title: title?.trim().isNotEmpty == true
            ? title!.trim()
            : '${scene.title} Copy',
        relationships: const [],
        createdAt: now,
        updatedAt: now,
      ),
    );
    return save(
      _withChapter(
        manuscript,
        chapter.copyWith(scenes: ordered, updatedAt: now),
      ),
      changed: [copyId],
      changeType: AuditChangeType.duplicated,
      metadata: {'duplicatedFrom': sceneId},
      timestamp: now,
    );
  }

  Future<ManuscriptProjectSummary> duplicateChapter(
    ManuscriptProjectSummary manuscript,
    String chapterId, {
    String? newId,
    String? title,
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final chapter = manuscript.chapterById(chapterId);
    if (chapter == null) throw StateError('Unknown chapter: $chapterId');
    final now = (timestamp ?? DateTime.now()).toUtc();
    final copyId = newId ?? ManuscriptId.create('chapter');
    await _requireFreeEntityId(copyId);
    final sceneIds = <String>[];
    final scenes = <ManuscriptScene>[];
    for (final scene in chapter.scenes) {
      final sceneCopyId = ManuscriptId.create('scene');
      await _requireFreeEntityId(sceneCopyId);
      sceneIds.add(sceneCopyId);
      scenes.add(scene.copyWith(
        id: sceneCopyId,
        chapterId: copyId,
        relationships: const [],
        createdAt: now,
        updatedAt: now,
      ));
    }
    final ordered = [...manuscript.chapters]
      ..sort((left, right) => left.order.compareTo(right.order));
    final index = ordered.indexWhere((item) => item.id == chapterId);
    ordered.insert(
      index + 1,
      chapter.copyWith(
        id: copyId,
        title: title?.trim().isNotEmpty == true
            ? title!.trim()
            : '${chapter.title} Copy',
        linkedChapterIds: const [],
        scenes: scenes,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return save(
      manuscript.copyWith(chapters: ordered),
      changed: [copyId, ...sceneIds],
      changeType: AuditChangeType.duplicated,
      metadata: {'duplicatedFrom': chapterId},
      timestamp: now,
    );
  }

  /// The impact of deleting a manuscript node, expressed with the shared
  /// [SafeDeleteAnalysis] model so the Studio can warn before it removes work.
  Future<SafeDeleteAnalysis?> analyzeDelete(
    ManuscriptProjectSummary manuscript,
    String nodeId,
  ) async {
    final chapter = manuscript.chapterById(nodeId);
    final scene = manuscript.sceneById(nodeId);
    if (chapter == null && scene == null) return null;
    final kind =
        chapter != null ? ManuscriptNodeKind.chapter : ManuscriptNodeKind.scene;
    final incoming = await _inspectConnections(nodeId, incoming: true);
    final outgoing = await _inspectConnections(nodeId, incoming: false);
    final references = <ReferenceInspection>[
      for (final inspection in [...incoming, ...outgoing])
        ReferenceInspection(
          kind: _referenceKindFor(
            inspection.source.id == nodeId
                ? inspection.target.type
                : inspection.source.type,
          ),
          entity: inspection.source.id == nodeId
              ? inspection.target
              : inspection.source,
          connectionId: inspection.id,
          connectionType: inspection.typeId,
          incoming: inspection.target.id == nodeId,
        ),
    ];
    final versions = await history.getVersionHistory(recordId: nodeId);
    final audits = await history.getAuditHistory(recordId: nodeId);
    final childScenes = chapter?.scenes.map((item) => item.id).toList() ??
        const <String>[];
    final words = chapter?.wordCount ?? scene?.wordCount ?? 0;
    final warnings = <String>[
      if (references.isNotEmpty)
        '${references.length} connected record(s) reference this '
            '${kind.label.toLowerCase()}.',
      if (childScenes.isNotEmpty)
        'Deleting this chapter also deletes ${childScenes.length} scene(s).',
      if (words > 0) '$words word(s) of drafted prose will be removed.',
    ];
    final blocking = <String>[
      if (!canEditCanon)
        'The manuscript is Canon and the $activeBranchId branch is active.',
      if (kind == ManuscriptNodeKind.chapter && manuscript.chapters.length <= 1)
        'A manuscript must keep at least one chapter.',
    ];
    return SafeDeleteAnalysis(
      recordId: nodeId,
      recordType: kind.typeId,
      disposition: blocking.isNotEmpty
          ? SafeDeleteDisposition.blocked
          : (warnings.isEmpty
              ? SafeDeleteDisposition.safe
              : SafeDeleteDisposition.safeWithWarnings),
      blockingReasons: List.unmodifiable(blocking),
      warnings: List.unmodifiable(warnings),
      incomingConnections: List.unmodifiable(incoming),
      outgoingConnections: List.unmodifiable(outgoing),
      references: List.unmodifiable(references),
      legacyReferences: const [],
      affectedBranches: const [],
      versionCount: versions.length,
      auditCount: audits.length,
      affectedRecords: List.unmodifiable(
        references.map((reference) => reference.entity.id).toSet(),
      ),
      affectedManuscriptNodes: List.unmodifiable(childScenes),
      templateDependentRecordIds: const [],
      archived: false,
      softDeleted: false,
      physicallyDeletable: blocking.isEmpty,
    );
  }

  /// Deletes a scene after [analyzeDelete] has been shown to the writer.
  ///
  /// Connections that pointed at the scene are removed through the shared
  /// [ConnectionEngine], so no relationship is left dangling and every removal
  /// is audited. Connected records themselves are never touched.
  Future<ManuscriptProjectSummary> deleteScene(
    ManuscriptProjectSummary manuscript,
    String sceneId, {
    required bool confirmed,
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    if (!confirmed) return manuscript;
    final chapter = manuscript.chapterOfScene(sceneId);
    final scene = manuscript.sceneById(sceneId);
    if (chapter == null || scene == null) {
      throw StateError('Unknown scene: $sceneId');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final node = ManuscriptStore.manuscriptNodeForScene(scene, projectId);
    await _disconnectAll(sceneId, timestamp: now);
    final next = await save(
      _withChapter(
        manuscript,
        chapter.copyWith(
          scenes: chapter.scenes.where((item) => item.id != sceneId).toList(),
          updatedAt: now,
        ),
      ),
      changed: [chapter.id],
      timestamp: now,
    );
    await _appendDeletionHistory(node, timestamp: now);
    await repository.removeManuscriptNodes([sceneId]);
    return next;
  }

  Future<ManuscriptProjectSummary> deleteChapter(
    ManuscriptProjectSummary manuscript,
    String chapterId, {
    required bool confirmed,
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    if (!confirmed) return manuscript;
    final chapter = manuscript.chapterById(chapterId);
    if (chapter == null) throw StateError('Unknown chapter: $chapterId');
    if (manuscript.chapters.length <= 1) {
      throw StateError('A manuscript must keep at least one chapter.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final nodes = <ManuscriptNodeReference>[
      ManuscriptStore.manuscriptNodeForChapter(chapter, projectId),
      for (final scene in chapter.scenes)
        ManuscriptStore.manuscriptNodeForScene(scene, projectId),
    ];
    await _disconnectAll(chapterId, timestamp: now);
    for (final scene in chapter.scenes) {
      await _disconnectAll(scene.id, timestamp: now);
    }
    final remaining = [
      for (final item in manuscript.chapters)
        if (item.id != chapterId)
          item.copyWith(
            linkedChapterIds: item.linkedChapterIds
                .where((linked) => linked != chapterId)
                .toList(),
          ),
    ];
    final next = await save(
      manuscript.copyWith(chapters: remaining),
      changed: [
        for (final item in remaining)
          if (item.linkedChapterIds.length !=
              manuscript.chapterById(item.id)!.linkedChapterIds.length)
            item.id,
      ],
      timestamp: now,
    );
    for (final node in nodes) {
      await _appendDeletionHistory(node, timestamp: now);
    }
    await repository.removeManuscriptNodes(
      nodes.map((node) => node.id).toList(),
    );
    return next;
  }

  Future<void> _disconnectAll(String nodeId, {DateTime? timestamp}) async {
    for (final link in await repository.backlinks(nodeId)) {
      await connections.disconnect(link.id, timestamp: timestamp);
    }
  }

  Future<void> _requireFreeEntityId(String id) async {
    if (await repository.recordById(id) != null ||
        await repository.manuscriptNodeById(id) != null) {
      throw StateError('Entity id $id is already in use.');
    }
  }

  // --- Connected records -------------------------------------------------

  /// Connection types that can join [nodeKind] to [recordTypeId], read from
  /// the shared connection registry.
  Future<List<ConnectionTypeDefinition>> connectionTypesFor({
    required ManuscriptNodeKind nodeKind,
    required String recordTypeId,
  }) async {
    final registry = await records.connectionRegistry();
    return registry.definitions.where((definition) {
      final forward = definition.permits(recordTypeId, nodeKind.typeId);
      final reverse = definition.permits(nodeKind.typeId, recordTypeId);
      return forward || reverse;
    }).toList()
      ..sort((left, right) => left.displayName.compareTo(right.displayName));
  }

  /// Connects a manuscript node to a record in another Studio.
  ///
  /// The direction is chosen from the connection type: `appearsIn` runs
  /// record -> scene, while a scene-owned type runs scene -> record.
  Future<RecordLink> connectNode({
    required String nodeId,
    required String recordId,
    required String typeId,
    String label = '',
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final node = await repository.manuscriptNodeById(nodeId);
    if (node == null || node.projectId != projectId) {
      throw StateError('Unknown manuscript node: $nodeId');
    }
    final record = await repository.recordById(recordId);
    if (record == null || (record.projectId ?? record.scopeId) != projectId) {
      throw StateError('Unknown record: $recordId');
    }
    final registry = await records.connectionRegistry();
    final definition = registry.resolve(typeId);
    final recordIsSource = definition.permits(record.typeId, node.nodeType);
    final direction = definition.direction == ConnectionDirection.directed
        ? RecordLinkDirection.directed
        : RecordLinkDirection.undirected;
    return connections.connect(
      sourceId: recordIsSource ? recordId : nodeId,
      targetId: recordIsSource ? nodeId : recordId,
      typeId: typeId,
      label: label,
      direction: direction,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  Future<void> disconnectNode(String linkId, {DateTime? timestamp}) async {
    _requireCanonEditable();
    await connections.disconnect(linkId, timestamp: timestamp);
  }

  /// Every record connected to [nodeId], resolved for display and navigation.
  Future<List<ManuscriptConnection>> connectionsFor(String nodeId) async {
    final node = await repository.manuscriptNodeById(nodeId);
    if (node == null || node.projectId != projectId) return const [];
    final registry = await records.connectionRegistry();
    final results = <ManuscriptConnection>[];
    for (final link in await repository.backlinks(nodeId)) {
      final otherId = link.sourceId == nodeId ? link.targetId : link.sourceId;
      final record = await repository.recordById(otherId);
      final otherNode = record == null
          ? await repository.manuscriptNodeById(otherId)
          : null;
      // Read from this node's side: the inverse label when the edge points
      // inward, the display name when it points outward. The forward name in
      // both directions made a scene's panel read "Appears in Kali Vale",
      // which inverts the relationship the author recorded.
      final incoming = link.targetId == nodeId;
      String displayName;
      try {
        final definition = registry.resolve(link.typeId);
        displayName =
            incoming ? definition.inverseLabel : definition.displayName;
        if (displayName.isEmpty) displayName = link.typeId;
      } on StateError {
        displayName = link.typeId;
      }
      results.add(ManuscriptConnection(
        link: link,
        nodeId: nodeId,
        recordId: otherId,
        recordType: record?.typeId ?? otherNode?.nodeType ?? 'unknown',
        title: record?.title ?? otherNode?.title ?? 'Missing reference',
        destination: searchDestinationForType(
          record?.typeId ?? otherNode?.nodeType ?? '',
        ),
        incoming: incoming,
        displayName: displayName,
        exists: record != null || otherNode != null,
      ));
    }
    results.sort((left, right) => left.title.compareTo(right.title));
    return results;
  }

  /// Records in this project that a manuscript node can be connected to.
  Future<List<AuthorRecord>> connectableRecords() async {
    final all = await repository.recordsByProject(projectId);
    return all
        .where((record) => record.status == AuthorRecordStatus.active)
        .toList()
      ..sort((left, right) => left.title.compareTo(right.title));
  }

  // --- Search and filtering ---------------------------------------------

  /// Full-text manuscript search, answered by the shared universal index.
  Future<List<SearchResult>> searchManuscript(String query) async {
    final results = await search.searchAll(
      query,
      filter: UniversalSearchFilter(
        projectId: projectId,
        branchId: activeBranchId,
      ),
    );
    return results
        .where((result) =>
            result.recordType == 'scene' ||
            result.recordType == 'chapter' ||
            result.recordType == 'book')
        .toList();
  }

  /// Scenes in [manuscript] that satisfy [filter].
  ///
  /// The text query is matched against the loaded manuscript so scene prose -
  /// which lives only in the manuscript store - is searchable alongside the
  /// indexed metadata.
  Future<List<ManuscriptSceneMatch>> filterScenes(
    ManuscriptProjectSummary manuscript,
    ManuscriptFilter filter,
  ) async {
    final connected = <String, Set<String>>{};
    if (filter.onlyUnconnected || filter.connectedRecordId.trim().isNotEmpty) {
      for (final chapter in manuscript.chapters) {
        for (final scene in chapter.scenes) {
          connected[scene.id] = {
            for (final link in await repository.backlinks(scene.id))
              link.sourceId == scene.id ? link.targetId : link.sourceId,
          };
        }
      }
    }
    final query = filter.query.trim().toLowerCase();
    final matches = <ManuscriptSceneMatch>[];
    final orderedChapters = [...manuscript.chapters]
      ..sort((left, right) => left.order.compareTo(right.order));
    for (final chapter in orderedChapters) {
      if (filter.chapterIds.isNotEmpty &&
          !filter.chapterIds.contains(chapter.id)) {
        continue;
      }
      final orderedScenes = [...chapter.scenes]
        ..sort((left, right) => left.order.compareTo(right.order));
      for (final scene in orderedScenes) {
        if (filter.statuses.isNotEmpty &&
            !filter.statuses.contains(scene.status)) {
          continue;
        }
        if (filter.pov.trim().isNotEmpty &&
            scene.pov.trim().toLowerCase() !=
                filter.pov.trim().toLowerCase()) {
          continue;
        }
        if (filter.location.trim().isNotEmpty &&
            scene.location.trim().toLowerCase() !=
                filter.location.trim().toLowerCase()) {
          continue;
        }
        if (filter.onlyEmpty && scene.wordCount > 0) continue;
        final links = connected[scene.id] ?? const <String>{};
        if (filter.onlyUnconnected && links.isNotEmpty) continue;
        if (filter.connectedRecordId.trim().isNotEmpty &&
            !links.contains(filter.connectedRecordId.trim())) {
          continue;
        }
        var snippet = '';
        if (query.isNotEmpty) {
          final haystack = [
            scene.title,
            scene.content,
            scene.notes,
            scene.pov,
            scene.location,
            scene.timeLabel,
            chapter.title,
          ].join('\n').toLowerCase();
          final index = haystack.indexOf(query);
          if (index < 0) continue;
          snippet = _snippet(scene, query);
        }
        matches.add(ManuscriptSceneMatch(
          chapter: chapter,
          scene: scene,
          snippet: snippet,
        ));
      }
    }
    return matches;
  }

  // --- Progress ----------------------------------------------------------

  ManuscriptProgress progressFor(
    ManuscriptProjectSummary manuscript, {
    int goalWords = 0,
    ManuscriptChapter? chapter,
    ManuscriptScene? scene,
    DateTime? today,
  }) {
    final day = (today ?? DateTime.now()).toUtc();
    final scenes = scene != null
        ? [scene]
        : chapter != null
            ? chapter.scenes
            : [
                for (final item in manuscript.chapters) ...item.scenes,
              ];
    final statusCounts = <ManuscriptNodeStatus, int>{
      for (final status in ManuscriptNodeStatus.values) status: 0,
    };
    var words = 0;
    var todayWords = 0;
    for (final item in scenes) {
      words += item.wordCount;
      statusCounts[item.status] = (statusCounts[item.status] ?? 0) + 1;
      final updated = item.updatedAt.toUtc();
      if (updated.year == day.year &&
          updated.month == day.month &&
          updated.day == day.day) {
        todayWords += item.wordCount;
      }
    }
    return ManuscriptProgress(
      wordCount: words,
      goalWords: goalWords,
      chapterCount: scene != null
          ? 1
          : chapter != null
              ? 1
              : manuscript.chapters.length,
      sceneCount: scenes.length,
      statusCounts: Map.unmodifiable(statusCounts),
      wordsWrittenToday: todayWords,
    );
  }

  // --- Validation --------------------------------------------------------

  /// Structural and connected-data problems across the manuscript.
  Future<List<ManuscriptValidationIssue>> validateManuscript(
    ManuscriptProjectSummary manuscript,
  ) async {
    final issues = <ManuscriptValidationIssue>[];
    if (manuscript.chapters.isEmpty) {
      issues.add(const ManuscriptValidationIssue(
        code: 'empty-manuscript',
        message: 'The manuscript has no chapters yet.',
        nodeKind: ManuscriptNodeKind.manuscript,
        isError: true,
      ));
    }
    final chapterIds = manuscript.chapters.map((item) => item.id).toSet();
    final seenTitles = <String, String>{};
    for (final chapter in manuscript.chapters) {
      if (chapter.title.trim().isEmpty) {
        issues.add(ManuscriptValidationIssue(
          code: 'missing-title',
          message: 'A chapter has no title.',
          nodeId: chapter.id,
          nodeKind: ManuscriptNodeKind.chapter,
          isError: true,
        ));
      }
      if (chapter.scenes.isEmpty) {
        issues.add(ManuscriptValidationIssue(
          code: 'empty-chapter',
          message: '${chapter.title} has no scenes.',
          nodeId: chapter.id,
          nodeKind: ManuscriptNodeKind.chapter,
        ));
      }
      for (final linkedId in chapter.linkedChapterIds) {
        if (!chapterIds.contains(linkedId)) {
          issues.add(ManuscriptValidationIssue(
            code: 'broken-reference',
            message:
                '${chapter.title} links to a chapter that no longer exists.',
            nodeId: chapter.id,
            nodeKind: ManuscriptNodeKind.chapter,
            isError: true,
          ));
        }
      }
      for (final scene in chapter.scenes) {
        final key = '${chapter.id}:${scene.title.trim().toLowerCase()}';
        if (scene.title.trim().isEmpty) {
          issues.add(ManuscriptValidationIssue(
            code: 'missing-title',
            message: 'A scene in ${chapter.title} has no title.',
            nodeId: scene.id,
            isError: true,
          ));
        } else if (seenTitles.containsKey(key)) {
          issues.add(ManuscriptValidationIssue(
            code: 'duplicate-title',
            message:
                '${chapter.title} has more than one scene called '
                '"${scene.title}".',
            nodeId: scene.id,
          ));
        } else {
          seenTitles[key] = scene.id;
        }
        if (scene.status == ManuscriptNodeStatus.complete &&
            scene.wordCount == 0) {
          issues.add(ManuscriptValidationIssue(
            code: 'empty-complete-scene',
            message: '${scene.title} is marked Complete but has no prose.',
            nodeId: scene.id,
          ));
        }
        for (final relationship in scene.relationships) {
          final targetId = relationship.targetId.trim();
          if (targetId.isEmpty) continue;
          final exists = await repository.recordById(targetId) != null ||
              await repository.manuscriptNodeById(targetId) != null;
          if (!exists) {
            issues.add(ManuscriptValidationIssue(
              code: 'broken-reference',
              message:
                  '${scene.title} references "${relationship.label.isEmpty ? targetId : relationship.label}", '
                  'which no longer exists.',
              nodeId: scene.id,
              isError: true,
            ));
          }
        }
        for (final link in await repository.backlinks(scene.id)) {
          final otherId =
              link.sourceId == scene.id ? link.targetId : link.sourceId;
          final record = await repository.recordById(otherId);
          final node = record == null
              ? await repository.manuscriptNodeById(otherId)
              : null;
          if (record == null && node == null) {
            issues.add(ManuscriptValidationIssue(
              code: 'broken-connection',
              message: '${scene.title} has a connection to a missing record.',
              nodeId: scene.id,
              isError: true,
            ));
          }
        }
      }
    }
    return issues;
  }

  // --- Continuity Intelligence -------------------------------------------

  ContinuityActionService get continuityActions => ContinuityActionService(
        projectId: projectId,
        repository: repository,
        activeBranchId: activeBranchId,
      );

  TimelineService get timeline =>
      TimelineService(projectId: projectId, repository: repository);

  /// Continuity findings for one scene or chapter.
  ///
  /// Inputs come from the shared record store and connection engine; the
  /// warnings themselves are produced by the existing [ContinuityAnalyzer]
  /// through [ManuscriptContinuityIntelligence].
  Future<ManuscriptContinuityReport> analyzeContinuity(
    ManuscriptProjectSummary manuscript,
    String nodeId, {
    ManuscriptContinuityIntelligence intelligence =
        const ManuscriptContinuityIntelligence(),
  }) async {
    final chapter = manuscript.chapterById(nodeId);
    final scene = manuscript.sceneById(nodeId);
    if (chapter == null && scene == null) {
      return ManuscriptContinuityReport.empty;
    }
    final projectRecords = await connectableRecords();
    final chronology = await sceneChronology(manuscript);
    final known = ManuscriptContinuityIntelligence.knownRecords(projectRecords);
    final knownNames = ManuscriptContinuityIntelligence.knownNames(
      projectRecords,
    );
    if (chapter != null) {
      final connected = <String, Set<String>>{};
      for (final item in chapter.scenes) {
        connected[item.id] = await _connectedIds(item.id);
      }
      return intelligence.analyzeChapter(
        chapter: chapter,
        records: known,
        connectedIds: connected,
        knownNames: knownNames,
        chronology: chronology,
      );
    }
    final owner = manuscript.chapterOfScene(nodeId)!;
    final ordered = [...owner.scenes]
      ..sort((left, right) => left.order.compareTo(right.order));
    final index = ordered.indexWhere((item) => item.id == nodeId);
    return intelligence.analyzeScene(
      scene: scene!,
      chapter: owner,
      records: known,
      connectedIds: await _connectedIds(nodeId),
      knownNames: knownNames,
      previousScene: index <= 0 ? null : ordered[index - 1],
      chronology: chronology,
    );
  }

  Future<Set<String>> _connectedIds(String nodeId) async => {
        for (final link in await repository.backlinks(nodeId))
          link.sourceId == nodeId ? link.targetId : link.sourceId,
      };

  /// The earliest timeline position each scene is connected to.
  ///
  /// Positions come from the existing timeline calendars, so the chronology
  /// rule agrees with Timeline Studio rather than inventing its own ordering.
  Future<Map<String, num>> sceneChronology(
    ManuscriptProjectSummary manuscript,
  ) async {
    final positions = <String, num>{};
    final resolved = <String, num?>{};
    for (final chapter in manuscript.chapters) {
      for (final scene in chapter.scenes) {
        for (final id in await _connectedIds(scene.id)) {
          if (!resolved.containsKey(id)) {
            resolved[id] = await _timelinePosition(id);
          }
          final position = resolved[id];
          if (position == null) continue;
          final current = positions[scene.id];
          if (current == null || position < current) {
            positions[scene.id] = position;
          }
        }
      }
    }
    return positions;
  }

  Future<num?> _timelinePosition(String recordId) async {
    final record = await repository.recordById(recordId);
    if (record == null) return null;
    final raw = record.fields['start'];
    final json = raw is List && raw.isNotEmpty
        ? (raw.first is Map ? Map<String, Object?>.from(raw.first as Map) : null)
        : (raw is Map ? Map<String, Object?>.from(raw) : null);
    if (json == null) return null;
    final date = TimelineDate.fromJson(json);
    if (!date.isDated || date.calendarId.isEmpty) return null;
    final calendar = await timeline.getCalendar(date.calendarId);
    if (calendar == null) return null;
    return calendar.ordinal(date);
  }

  /// Applies one continuity recommendation.
  ///
  /// `create` and `link` recommendations are handed to the existing
  /// [ContinuityActionService]; `review` recommendations edit the manuscript
  /// through this service so scene prose and metadata keep one owner. Nothing
  /// is applied unless [confirmed] is true.
  Future<ContinuityActionResult> resolveContinuity(
    ManuscriptProjectSummary manuscript,
    ContinuityIntegrityIssue issue,
    ManuscriptContinuityFinding finding, {
    required bool confirmed,
    String? name,
    DateTime? timestamp,
  }) async {
    if (!canEditCanon) {
      return ContinuityActionResult(
        status: ContinuityActionStatus.failed,
        warningRemains: true,
        message: 'The manuscript is Canon and the $activeBranchId branch is '
            'active. Leave the branch to resolve this recommendation.',
      );
    }
    switch (finding.actionKind) {
      case ContinuityActionKind.create:
        return continuityActions.createForRecommendation(
          issue,
          name: name ?? finding.missingName,
          confirmed: confirmed,
          timestamp: timestamp,
        );
      case ContinuityActionKind.link:
        final targetId = finding.targetId;
        if (targetId == null) {
          return const ContinuityActionResult(
            status: ContinuityActionStatus.failed,
            warningRemains: true,
            message: 'This recommendation has no record to link.',
          );
        }
        return _link(issue, finding, targetId, confirmed, timestamp);
      case ContinuityActionKind.review:
        return _review(manuscript, finding, confirmed, timestamp);
    }
  }

  Future<ContinuityActionResult> _link(
    ContinuityIntegrityIssue issue,
    ManuscriptContinuityFinding finding,
    String targetId,
    bool confirmed,
    DateTime? timestamp,
  ) async {
    if (!confirmed) {
      return const ContinuityActionResult(
        status: ContinuityActionStatus.cancelled,
        warningRemains: true,
        message: 'No changes were made.',
      );
    }
    try {
      final link = await connectNode(
        nodeId: finding.nodeId,
        recordId: targetId,
        typeId: finding.connectionTypeId,
        timestamp: timestamp,
      );
      return ContinuityActionResult(
        status: ContinuityActionStatus.resolved,
        warningRemains: false,
        linkId: link.id,
        message: 'The recommendation was resolved.',
      );
    } catch (error) {
      return ContinuityActionResult(
        status: ContinuityActionStatus.failed,
        warningRemains: true,
        message: error.toString(),
      );
    }
  }

  Future<ContinuityActionResult> _review(
    ManuscriptProjectSummary manuscript,
    ManuscriptContinuityFinding finding,
    bool confirmed,
    DateTime? timestamp,
  ) async {
    if (!confirmed) {
      return const ContinuityActionResult(
        status: ContinuityActionStatus.cancelled,
        warningRemains: true,
        message: 'No changes were made.',
      );
    }
    final targetId = finding.targetId;
    try {
      if (finding.warning.type == ContinuityWarningType.missingPovPresence &&
          targetId != null) {
        final link = await connectNode(
          nodeId: finding.nodeId,
          recordId: targetId,
          typeId: finding.connectionTypeId,
          timestamp: timestamp,
        );
        await updateSceneMetadata(
          manuscript,
          finding.nodeId,
          pov: finding.reviewValue.isEmpty ? null : finding.reviewValue,
          timestamp: timestamp,
        );
        return ContinuityActionResult(
          status: ContinuityActionStatus.resolved,
          warningRemains: false,
          linkId: link.id,
          recordId: targetId,
          message: 'The recommendation was resolved.',
        );
      }
      return const ContinuityActionResult(
        status: ContinuityActionStatus.warningRemains,
        warningRemains: true,
        message: 'This recommendation needs a manual decision in the '
            'manuscript before it can be cleared.',
      );
    } catch (error) {
      return ContinuityActionResult(
        status: ContinuityActionStatus.failed,
        warningRemains: true,
        message: error.toString(),
      );
    }
  }

  // --- Inspector and history --------------------------------------------

  Future<ManuscriptNodeInspection?> inspectNode(
    ManuscriptProjectSummary manuscript,
    String nodeId,
  ) async {
    final chapter = manuscript.chapterById(nodeId);
    final scene = manuscript.sceneById(nodeId);
    if (chapter == null && scene == null) return null;
    final kind =
        chapter != null ? ManuscriptNodeKind.chapter : ManuscriptNodeKind.scene;
    final node = chapter != null
        ? ManuscriptStore.manuscriptNodeForChapter(chapter, projectId)
        : ManuscriptStore.manuscriptNodeForScene(scene!, projectId);
    final incoming = await _inspectConnections(nodeId, incoming: true);
    final outgoing = await _inspectConnections(nodeId, incoming: false);
    final references = <ReferenceInspection>[
      for (final inspection in [...incoming, ...outgoing])
        ReferenceInspection(
          kind: _referenceKindFor(
            inspection.source.id == nodeId
                ? inspection.target.type
                : inspection.source.type,
          ),
          entity: inspection.source.id == nodeId
              ? inspection.target
              : inspection.source,
          connectionId: inspection.id,
          connectionType: inspection.typeId,
          incoming: inspection.target.id == nodeId,
        ),
    ];
    final versions = await history.getVersionHistory(recordId: nodeId);
    final audits = await history.getAuditHistory(recordId: nodeId);
    final validation = (await validateManuscript(manuscript))
        .where((issue) => issue.nodeId == nodeId)
        .toList();
    final issues = <RecordValidationIssue>[
      for (final issue in validation)
        RecordValidationIssue(
          code: issue.code,
          message: issue.message,
          severity: issue.isError
              ? RecordValidationSeverity.error
              : RecordValidationSeverity.warning,
        ),
      for (final inspection in [...incoming, ...outgoing])
        if (!inspection.valid)
          RecordValidationIssue(
            code: inspection.source.exists && inspection.target.exists
                ? 'invalid-connection'
                : 'broken-reference',
            message: inspection.validationMessage ??
                'Connection ${inspection.id} is invalid.',
          ),
    ];
    return ManuscriptNodeInspection(
      nodeId: nodeId,
      nodeKind: kind,
      title: node.title,
      projectId: projectId,
      branchId: activeBranchId,
      createdAt: node.createdAt,
      updatedAt: node.updatedAt,
      wordCount: chapter?.wordCount ?? scene?.wordCount ?? 0,
      status: chapter?.status ?? scene!.status,
      outgoingConnections: List.unmodifiable(outgoing),
      incomingConnections: List.unmodifiable(incoming),
      references: List.unmodifiable(references),
      history: HistoryInspection(
        versions: List.unmodifiable(versions),
        auditEvents: List.unmodifiable(audits),
        latestVersion: versions.isEmpty ? null : versions.last,
        latestAuditEvent: audits.isEmpty ? null : audits.last,
      ),
      scope: ScopeInspection(
        projectId: projectId,
        branchId: activeBranchId,
        canonStatus: CanonStatus.canon,
        lifecycleStatus: AuthorRecordStatus.active,
        branchState: BranchRecordState.inherited,
        visible: true,
      ),
      validation: ValidationInspection(
        state: issues.any(
                (issue) => issue.severity == RecordValidationSeverity.error)
            ? InspectionValidationState.error
            : (issues.isEmpty
                ? InspectionValidationState.valid
                : InspectionValidationState.warning),
        issues: List.unmodifiable(issues),
      ),
      safeDelete: SafeDeleteInspection(
        incomingConnectionCount: incoming.length,
        outgoingConnectionCount: outgoing.length,
        knownReferenceCount: references.length,
        branchDependencyCount: 0,
        versionCount: versions.length,
        dependentEntityIds: List.unmodifiable(
          references.map((reference) => reference.entity.id).toSet(),
        ),
      ),
      capabilities: const InspectionCapabilities(
        supportedReferenceKinds: [
          ReferenceKind.chapter,
          ReferenceKind.scene,
          ReferenceKind.codex,
          ReferenceKind.timeline,
          ReferenceKind.plot,
          ReferenceKind.world,
          ReferenceKind.universalRecord,
        ],
        unsupportedReferenceKinds: [ReferenceKind.map],
        limitations: [
          'Manuscript nodes are Canon: branch overrides are not yet supported.',
        ],
      ),
    );
  }

  Future<List<RecordVersion>> historyFor(String nodeId) =>
      history.getVersionHistory(recordId: nodeId);

  Future<List<AuditEvent>> auditFor(String nodeId) =>
      history.getAuditHistory(recordId: nodeId);

  /// Restores a node's title, status and metadata from a stored version.
  ///
  /// Scene prose is never rolled back from history, because history stores the
  /// shared node reference rather than a copy of the manuscript body.
  Future<ManuscriptProjectSummary> restoreVersion(
    ManuscriptProjectSummary manuscript,
    String versionId, {
    DateTime? timestamp,
  }) async {
    _requireCanonEditable();
    final version = await history.getVersion(versionId);
    if (version == null) {
      throw StateError('Unknown version: $versionId');
    }
    final node = ManuscriptNodeReference.fromJson(
      Map<String, dynamic>.from(version.snapshot),
    );
    if (node.projectId != projectId) {
      throw StateError('Version $versionId belongs to another project.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final status = ManuscriptNodeStatusX.fromId(
      node.extensionData['status'] as String?,
    );
    final chapter = manuscript.chapterById(node.id);
    if (chapter != null) {
      return save(
        _withChapter(
          manuscript,
          chapter.copyWith(
            title: node.title,
            status: status,
            pov: node.extensionData['pov'] as String? ?? chapter.pov,
            summary: node.extensionData['summary'] as String? ?? chapter.summary,
            updatedAt: now,
          ),
        ),
        changed: [node.id],
        changeType: AuditChangeType.restored,
        summary: 'Restored ${node.title} from $versionId',
        metadata: {'restoredVersionId': versionId},
        timestamp: now,
      );
    }
    final scene = manuscript.sceneById(node.id);
    if (scene == null) {
      throw StateError('Version $versionId has no matching manuscript node.');
    }
    return save(
      _withScene(
        manuscript,
        scene.copyWith(
          title: node.title,
          status: status,
          pov: node.extensionData['pov'] as String? ?? scene.pov,
          location: node.extensionData['location'] as String? ?? scene.location,
          timeLabel:
              node.extensionData['timeLabel'] as String? ?? scene.timeLabel,
          notes: node.extensionData['notes'] as String? ?? scene.notes,
          updatedAt: now,
        ),
      ),
      changed: [node.id],
      changeType: AuditChangeType.restored,
      summary: 'Restored ${node.title} from $versionId',
      metadata: {'restoredVersionId': versionId},
      timestamp: now,
    );
  }

  // --- Internals ---------------------------------------------------------

  Future<List<ConnectionInspection>> _inspectConnections(
    String nodeId, {
    required bool incoming,
  }) async {
    final registry = await records.connectionRegistry();
    final links = incoming
        ? await repository.incomingLinks(nodeId)
        : await repository.outgoingLinks(nodeId);
    final inspections = <ConnectionInspection>[];
    for (final link in links) {
      final source = await _endpoint(link.sourceId);
      final target = await _endpoint(link.targetId);
      ConnectionTypeDefinition? definition;
      String? message;
      try {
        definition = registry.resolve(link.typeId);
        if (!source.exists || !target.exists) {
          message = 'Connection ${link.id} has a missing endpoint.';
        } else {
          registry.validateConnection(
            typeId: link.typeId,
            sourceTypeId: source.type,
            targetTypeId: target.type,
            metadata: link.metadata,
          );
        }
      } on StateError catch (error) {
        message = error.message;
      }
      inspections.add(ConnectionInspection(
        id: link.id,
        typeId: link.typeId,
        displayName: definition?.displayName ?? link.label,
        inverseLabel: definition?.inverseLabel ?? '',
        source: source,
        target: target,
        direction: link.direction,
        metadata: Map<String, Object?>.unmodifiable(link.metadata),
        temporalMetadata: Map<String, Object?>.unmodifiable({
          for (final entry in link.metadata.entries)
            if (const {
              'startDate',
              'endDate',
              'joinedDate',
              'leftDate',
              'status',
            }.contains(entry.key))
              entry.key: entry.value,
        }),
        temporalSupport: definition?.temporalSupport ?? false,
        branchId: activeBranchId,
        valid: message == null,
        validationMessage: message,
      ));
    }
    return inspections;
  }

  Future<InspectionEndpoint> _endpoint(String id) async {
    final record = await repository.recordById(id);
    if (record != null) {
      return InspectionEndpoint(
        id: record.id,
        type: record.typeId,
        title: record.title,
        projectId: record.projectId ?? record.scopeId,
        branchId: activeBranchId ?? record.branchId,
        exists: true,
      );
    }
    final node = await repository.manuscriptNodeById(id);
    if (node != null && node.projectId == projectId) {
      return InspectionEndpoint(
        id: node.id,
        type: node.nodeType,
        title: node.title,
        projectId: node.projectId,
        branchId: activeBranchId,
        exists: true,
      );
    }
    return InspectionEndpoint(
      id: id,
      type: 'unknown',
      title: 'Missing reference',
      projectId: projectId,
      branchId: activeBranchId,
      exists: false,
    );
  }

  /// Renumbers [scenes] from one so list position, not the stale stored
  /// order, decides the sequence the store persists.
  static List<ManuscriptScene> _sequenced(List<ManuscriptScene> scenes) => [
        for (final entry in scenes.asMap().entries)
          entry.value.order == entry.key + 1
              ? entry.value
              : entry.value.copyWith(order: entry.key + 1),
      ];

  /// Renumbers [chapters] from one, and every scene inside them.
  static List<ManuscriptChapter> _sequencedChapters(
    List<ManuscriptChapter> chapters,
  ) =>
      [
        for (final entry in chapters.asMap().entries)
          entry.value.copyWith(
            order: entry.key + 1,
            scenes: _sequenced(entry.value.scenes),
          ),
      ];

  ManuscriptProjectSummary _withChapter(
    ManuscriptProjectSummary manuscript,
    ManuscriptChapter chapter,
  ) =>
      manuscript.copyWith(chapters: [
        for (final item in manuscript.chapters)
          item.id == chapter.id ? chapter : item,
      ]);

  ManuscriptProjectSummary _withScene(
    ManuscriptProjectSummary manuscript,
    ManuscriptScene scene,
  ) =>
      manuscript.copyWith(chapters: [
        for (final chapter in manuscript.chapters)
          chapter.copyWith(scenes: [
            for (final item in chapter.scenes)
              item.id == scene.id ? scene : item,
          ]),
      ]);
}

ReferenceKind _referenceKindFor(String typeId) => switch (typeId) {
      'scene' => ReferenceKind.scene,
      'chapter' => ReferenceKind.chapter,
      'book' || 'manuscript' || 'part' => ReferenceKind.manuscript,
      'general-lore' ||
      'research-entry' ||
      'reference' ||
      'glossary-term' ||
      'codex-entry' =>
        ReferenceKind.codex,
      'historical-event' || 'timeline-event' => ReferenceKind.timeline,
      'plot-thread' => ReferenceKind.plot,
      'location' ||
      'place' ||
      'faction' ||
      'organisation' ||
      'world' ||
      'item' ||
      'artefact' =>
        ReferenceKind.world,
      'map' || 'map-marker' => ReferenceKind.map,
      _ => ReferenceKind.universalRecord,
    };

String _snippet(ManuscriptScene scene, String query) {
  final body = scene.content.trim().isEmpty ? scene.notes : scene.content;
  final index = body.toLowerCase().indexOf(query);
  if (index < 0) {
    return body.length <= 120 ? body : '${body.substring(0, 120)}...';
  }
  final start = (index - 40) < 0 ? 0 : index - 40;
  final end = (index + 80) > body.length ? body.length : index + 80;
  final prefix = start == 0 ? '' : '...';
  final suffix = end == body.length ? '' : '...';
  return '$prefix${body.substring(start, end).trim()}$suffix';
}
