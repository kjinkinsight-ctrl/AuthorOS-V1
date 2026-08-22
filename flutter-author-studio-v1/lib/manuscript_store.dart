import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/connected_domain.dart';
import 'persistence/authoros_database.dart';
import 'sync/manuscript_sync.dart';

class ManuscriptId {
  ManuscriptId._();

  static int _sequence = 0;

  static String create(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
}

enum ManuscriptNodeStatus {
  planned,
  draft,
  revising,
  complete,
}

extension ManuscriptNodeStatusX on ManuscriptNodeStatus {
  String get id => name;

  String get label => switch (this) {
        ManuscriptNodeStatus.planned => 'Planned',
        ManuscriptNodeStatus.draft => 'Draft',
        ManuscriptNodeStatus.revising => 'Revising',
        ManuscriptNodeStatus.complete => 'Complete',
      };

  static ManuscriptNodeStatus fromId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return ManuscriptNodeStatus.draft;
    }
    for (final status in ManuscriptNodeStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    return ManuscriptNodeStatus.draft;
  }
}

enum SceneRelationshipType {
  previousScene,
  nextScene,
  relatedScene,
  character,
  location,
  plotPoint,
  timelineEvent,
  researchItem,
  note,
}

extension SceneRelationshipTypeX on SceneRelationshipType {
  String get label => switch (this) {
        SceneRelationshipType.previousScene => 'Previous Scene',
        SceneRelationshipType.nextScene => 'Next Scene',
        SceneRelationshipType.relatedScene => 'Related Scene',
        SceneRelationshipType.character => 'Character',
        SceneRelationshipType.location => 'Location',
        SceneRelationshipType.plotPoint => 'Plot Point',
        SceneRelationshipType.timelineEvent => 'Timeline Event',
        SceneRelationshipType.researchItem => 'Research Item',
        SceneRelationshipType.note => 'Note',
      };

  static SceneRelationshipType fromId(String? value) {
    if (value == null) {
      return SceneRelationshipType.relatedScene;
    }
    for (final type in SceneRelationshipType.values) {
      if (type.name == value) {
        return type;
      }
    }
    return SceneRelationshipType.relatedScene;
  }
}

class SceneRelationship {
  const SceneRelationship({
    required this.id,
    required this.type,
    required this.targetId,
    this.label = '',
    this.metadata = const {},
  });

  final String id;
  final SceneRelationshipType type;
  final String targetId;
  final String label;
  final Map<String, String> metadata;

  SceneRelationship copyWith({
    String? id,
    SceneRelationshipType? type,
    String? targetId,
    String? label,
    Map<String, String>? metadata,
  }) =>
      SceneRelationship(
        id: id ?? this.id,
        type: type ?? this.type,
        targetId: targetId ?? this.targetId,
        label: label ?? this.label,
        metadata: metadata ?? this.metadata,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'type': type.name,
        'targetId': targetId,
        'label': label,
        'metadata': metadata,
      };

  factory SceneRelationship.fromJson(Map<String, dynamic> json) =>
      SceneRelationship(
        id: (json['id'] as String?) ?? '',
        type: SceneRelationshipTypeX.fromId(json['type'] as String?),
        targetId: (json['targetId'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        metadata: (json['metadata'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const {},
      );
}

class ManuscriptScene {
  const ManuscriptScene({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.order,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.pov = '',
    this.location = '',
    this.timeLabel = '',
    this.notes = '',
    this.relationships = const [],
  });

  final String id;
  final String chapterId;
  final String title;
  final int order;
  final String content;
  final ManuscriptNodeStatus status;
  final String pov;
  final String location;
  final String timeLabel;
  final String notes;
  final List<SceneRelationship> relationships;
  final DateTime createdAt;
  final DateTime updatedAt;

  ManuscriptScene copyWith({
    String? id,
    String? chapterId,
    String? title,
    int? order,
    String? content,
    ManuscriptNodeStatus? status,
    String? pov,
    String? location,
    String? timeLabel,
    String? notes,
    List<SceneRelationship>? relationships,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ManuscriptScene(
        id: id ?? this.id,
        chapterId: chapterId ?? this.chapterId,
        title: title ?? this.title,
        order: order ?? this.order,
        content: content ?? this.content,
        status: status ?? this.status,
        pov: pov ?? this.pov,
        location: location ?? this.location,
        timeLabel: timeLabel ?? this.timeLabel,
        notes: notes ?? this.notes,
        relationships: relationships ?? this.relationships,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  int get wordCount {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return trimmed.split(RegExp(r'\s+')).length;
  }

  Map<String, Object> toJson() => {
        'id': id,
        'chapterId': chapterId,
        'title': title,
        'order': order,
        'content': content,
        'status': status.name,
        'pov': pov,
        'location': location,
        'timeLabel': timeLabel,
        'notes': notes,
        'relationships': relationships.map((item) => item.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ManuscriptScene.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ManuscriptScene(
      id: (json['id'] as String?) ?? '',
      chapterId: (json['chapterId'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Untitled Scene',
      order: (json['order'] as int?) ?? 1,
      content: (json['content'] as String?) ?? '',
      status: ManuscriptNodeStatusX.fromId(json['status'] as String?),
      pov: (json['pov'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      timeLabel: (json['timeLabel'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
      relationships: (json['relationships'] as List? ?? const [])
          .map((item) => SceneRelationship.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? now,
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? now,
    );
  }
}

class ManuscriptChapter {
  const ManuscriptChapter({
    required this.id,
    required this.title,
    required this.order,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.summary = '',
    this.prompt = '',
    this.pov = '',
    this.linkedChapterIds = const [],
    this.scenes = const [],
  });

  final String id;
  final String title;
  final int order;
  final ManuscriptNodeStatus status;
  final String summary;
  final String prompt;
  final String pov;
  final List<String> linkedChapterIds;
  final List<ManuscriptScene> scenes;
  final DateTime createdAt;
  final DateTime updatedAt;

  ManuscriptChapter copyWith({
    String? id,
    String? title,
    int? order,
    ManuscriptNodeStatus? status,
    String? summary,
    String? prompt,
    String? pov,
    List<String>? linkedChapterIds,
    List<ManuscriptScene>? scenes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ManuscriptChapter(
        id: id ?? this.id,
        title: title ?? this.title,
        order: order ?? this.order,
        status: status ?? this.status,
        summary: summary ?? this.summary,
        prompt: prompt ?? this.prompt,
        pov: pov ?? this.pov,
        linkedChapterIds: linkedChapterIds ?? this.linkedChapterIds,
        scenes: scenes ?? this.scenes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  int get wordCount =>
      scenes.fold<int>(0, (sum, scene) => sum + scene.wordCount);

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'order': order,
        'status': status.name,
        'summary': summary,
        'prompt': prompt,
        'pov': pov,
        'linkedChapterIds': linkedChapterIds,
        'scenes': scenes.map((scene) => scene.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ManuscriptChapter.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final chapterId = (json['id'] as String?) ?? '';
    final scenes = (json['scenes'] as List? ?? const [])
        .map((item) =>
            ManuscriptScene.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();

    return ManuscriptChapter(
      id: chapterId,
      title: (json['title'] as String?) ?? 'Untitled Chapter',
      order: (json['order'] as int?) ?? 1,
      status: ManuscriptNodeStatusX.fromId(json['status'] as String?),
      summary: (json['summary'] as String?) ?? '',
      prompt: (json['prompt'] as String?) ?? '',
      pov: (json['pov'] as String?) ?? '',
      linkedChapterIds: (json['linkedChapterIds'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(),
      scenes: [
        for (final scene in scenes)
          scene.chapterId == chapterId
              ? scene
              : scene.copyWith(chapterId: chapterId),
      ],
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? now,
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? now,
    );
  }
}

class ManuscriptProjectSummary {
  const ManuscriptProjectSummary({
    required this.projectId,
    required this.manuscriptTitle,
    required this.chapters,
    required this.currentChapterId,
    required this.currentSceneId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.migration = const {},
  });

  final String projectId;
  final String manuscriptTitle;
  final List<ManuscriptChapter> chapters;
  final String currentChapterId;
  final String currentSceneId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final Map<String, String> migration;

  ManuscriptProjectSummary copyWith({
    String? manuscriptTitle,
    List<ManuscriptChapter>? chapters,
    String? currentChapterId,
    String? currentSceneId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    Map<String, String>? migration,
  }) =>
      ManuscriptProjectSummary(
        projectId: projectId,
        manuscriptTitle: manuscriptTitle ?? this.manuscriptTitle,
        chapters: chapters ?? this.chapters,
        currentChapterId: currentChapterId ?? this.currentChapterId,
        currentSceneId: currentSceneId ?? this.currentSceneId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version ?? this.version,
        migration: migration ?? this.migration,
      );

  int get chapterCount => chapters.length;

  int get sceneCount =>
      chapters.fold<int>(0, (sum, chapter) => sum + chapter.scenes.length);

  int get wordCount =>
      chapters.fold<int>(0, (sum, chapter) => sum + chapter.wordCount);

  double progressAgainst(int goalWords) {
    if (goalWords <= 0) {
      return 0;
    }
    return (wordCount / goalWords).clamp(0.0, 1.0);
  }

  ManuscriptChapter? chapterById(String id) {
    for (final chapter in chapters) {
      if (chapter.id == id) {
        return chapter;
      }
    }
    return null;
  }

  ManuscriptScene? sceneById(String id) {
    for (final chapter in chapters) {
      for (final scene in chapter.scenes) {
        if (scene.id == id) {
          return scene;
        }
      }
    }
    return null;
  }

  /// The chapter that owns [sceneId], or `null` when the scene is unknown.
  ManuscriptChapter? chapterOfScene(String sceneId) {
    for (final chapter in chapters) {
      for (final scene in chapter.scenes) {
        if (scene.id == sceneId) {
          return chapter;
        }
      }
    }
    return null;
  }

  /// A copy with chapter and scene orders renumbered from one, and every
  /// scene re-parented to the chapter that holds it.
  ManuscriptProjectSummary normalized() =>
      copyWith(chapters: _normalizedChapters(chapters));

  String exportAsSingleText() {
    final buffer = StringBuffer();
    final sortedChapters = [...chapters]
      ..sort((a, b) => a.order.compareTo(b.order));
    for (var chapterIndex = 0;
        chapterIndex < sortedChapters.length;
        chapterIndex++) {
      final chapter = sortedChapters[chapterIndex];
      buffer.writeln(chapter.title);
      if (chapter.prompt.trim().isNotEmpty) {
        buffer.writeln(chapter.prompt.trim());
      }
      final sortedScenes = [...chapter.scenes]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final scene in sortedScenes) {
        buffer.writeln();
        buffer.writeln(scene.title);
        if (scene.content.trim().isNotEmpty) {
          buffer.writeln(scene.content.trim());
        }
      }
      if (chapterIndex < sortedChapters.length - 1) {
        buffer.writeln();
        buffer.writeln();
      }
    }
    return buffer.toString().trim();
  }

  List<SceneCursor> orderedSceneCursors() {
    final result = <SceneCursor>[];
    final sortedChapters = [...chapters]
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final chapter in sortedChapters) {
      final sortedScenes = [...chapter.scenes]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final scene in sortedScenes) {
        result.add(SceneCursor(chapterId: chapter.id, sceneId: scene.id));
      }
    }
    return result;
  }

  Map<String, Object> toJson() => {
        'projectId': projectId,
        'manuscriptTitle': manuscriptTitle,
        'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
        'currentChapterId': currentChapterId,
        'currentSceneId': currentSceneId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'version': version,
        'migration': migration,
      };

  factory ManuscriptProjectSummary.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final chapters = (json['chapters'] as List? ?? const [])
        .map((item) =>
            ManuscriptChapter.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return ManuscriptProjectSummary(
      projectId: (json['projectId'] as String?) ?? '',
      manuscriptTitle: (json['manuscriptTitle'] as String?) ?? 'Manuscript',
      chapters: _normalizedChapters(chapters),
      currentChapterId: (json['currentChapterId'] as String?) ?? '',
      currentSceneId: (json['currentSceneId'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? now,
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? now,
      version: (json['version'] as int?) ?? 1,
      migration: (json['migration'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
    );
  }

  static List<ManuscriptChapter> _normalizedChapters(
      List<ManuscriptChapter> chapters) {
    final sorted = [...chapters]..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (var chapterIndex = 0; chapterIndex < sorted.length; chapterIndex++)
        sorted[chapterIndex].copyWith(
          order: chapterIndex + 1,
          scenes: [
            for (final entry in ([...sorted[chapterIndex].scenes]
                  ..sort((a, b) => a.order.compareTo(b.order)))
                .asMap()
                .entries)
              entry.value.copyWith(
                chapterId: sorted[chapterIndex].id,
                order: entry.key + 1,
              )
          ],
        )
    ];
  }
}

class SceneCursor {
  const SceneCursor({
    required this.chapterId,
    required this.sceneId,
  });

  final String chapterId;
  final String sceneId;
}

class ManuscriptChapterSeed {
  const ManuscriptChapterSeed({
    required this.title,
    this.prompt = '',
    this.status = 'Active',
    this.scenes = const [],
    this.linkedChapterIds = const [],
  });

  final String title;
  final String prompt;
  final String status;
  final List<String> scenes;
  final List<String> linkedChapterIds;
}

class ManuscriptStore {
  const ManuscriptStore({this.repository});

  final DriftConnectedDomainRepository? repository;

  DriftConnectedDomainRepository get _repository =>
      repository ?? authorOsRepository;

  static String _key(String projectId) => 'author_studio.manuscript.$projectId';

  static String _studioKey(String projectId) =>
      'author_studio.manuscript_studio.$projectId';

  static String _legacyBackupKey(String projectId) =>
      'author_studio.manuscript_legacy_backup.$projectId';

  static String _chaptersKey(String projectId) =>
      'author_studio.chapters.$projectId';

  Future<String> load(String projectId) async {
    final preferences = await SharedPreferences.getInstance();
    final encodedStudio = preferences.getString(_studioKey(projectId));
    if (encodedStudio != null && encodedStudio.isNotEmpty) {
      try {
        final decoded = jsonDecode(encodedStudio) as Map<String, dynamic>;
        return ManuscriptProjectSummary.fromJson(decoded).exportAsSingleText();
      } catch (_) {
        return preferences.getString(_key(projectId)) ?? '';
      }
    }
    return preferences.getString(_key(projectId)) ?? '';
  }

  Future<void> save(String projectId, String manuscript) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(projectId), manuscript);
  }

  Future<List<ManuscriptChapterSeed>> loadLegacyChapterSeeds(
    String projectId,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_chaptersKey(projectId));
    if (values == null || values.isEmpty) {
      return const [];
    }
    final seeds = <ManuscriptChapterSeed>[];
    for (final raw in values) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        seeds.add(
          ManuscriptChapterSeed(
            title: (decoded['title'] as String?) ?? 'Untitled Chapter',
            prompt: (decoded['prompt'] as String?) ?? '',
            status: (decoded['status'] as String?) ?? 'Active',
            scenes: (decoded['scenes'] as List? ?? const [])
                .map((value) => value.toString())
                .toList(),
            linkedChapterIds: (decoded['linkedChapterIds'] as List? ?? const [])
                .map((value) => value.toString())
                .toList(),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return seeds;
  }

  /// The stored manuscript for [projectId], or `null` when none was ever
  /// saved.
  ///
  /// The read-only counterpart to [loadStudio]. That method seeds and persists
  /// a starter manuscript when it finds none — reasonable for the project the
  /// author just opened, and recorded as risk R-21 in the Story Graph audit,
  /// but wrong for anything that surveys projects it is not opening. A series
  /// dashboard reading five books must not bring four manuscripts into
  /// existence to draw four empty bars.
  ///
  /// So this never migrates and never writes. A project with no manuscript
  /// reports `null`, which callers must render as "not started" rather than
  /// as an error or a zero they invented.
  Future<ManuscriptProjectSummary?> peekStudio(String projectId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_studioKey(projectId));
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return ManuscriptProjectSummary.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } catch (_) {
      // A malformed blob is not a manuscript. Repairing it is [loadStudio]'s
      // job, on a project the author actually opened; here it reads as absent.
      return null;
    }
  }

  Future<ManuscriptProjectSummary> loadStudio(
    String projectId, {
    required String manuscriptTitle,
    required List<ManuscriptChapterSeed> defaultChapters,
    String firstSceneTitle = 'Opening Scene',
  }) async {
    final stored = await peekStudio(projectId);
    if (stored != null) return stored;

    final migrated = await _migrateLegacyToStudio(
      projectId,
      manuscriptTitle: manuscriptTitle,
      defaultChapters: defaultChapters,
      firstSceneTitle: firstSceneTitle,
    );
    await saveStudio(migrated, persistLegacyText: false);
    return migrated;
  }

  static String _syncShadowKey(String projectId) =>
      'author_studio.manuscript_sync_shadow.$projectId';

  /// What this device believes the server already has, scene by scene.
  Future<ManuscriptSyncShadow> loadSyncShadow(String projectId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_syncShadowKey(projectId));
    if (encoded == null || encoded.isEmpty) {
      return const ManuscriptSyncShadow.empty();
    }
    try {
      return ManuscriptSyncShadow.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } catch (_) {
      // An unreadable shadow means every scene reads as dirty and re-uploads.
      // Wasteful, never wrong — the opposite mistake would silently skip
      // scenes that had never actually reached the server.
      return const ManuscriptSyncShadow.empty();
    }
  }

  Future<void> saveSyncShadow(
    String projectId,
    ManuscriptSyncShadow shadow,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _syncShadowKey(projectId),
      jsonEncode(shadow.toJson()),
    );
  }

  static String _structureFingerprintKey(String projectId) =>
      'author_studio.manuscript_sync_structure.$projectId';

  /// The outline as this device last sent it, so a save that changed only
  /// prose does not re-upload the chapter list.
  Future<String?> loadStructureFingerprint(String projectId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_structureFingerprintKey(projectId));
  }

  Future<void> saveStructureFingerprint(
    String projectId,
    String fingerprint,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _structureFingerprintKey(projectId),
      fingerprint,
    );
  }

  /// Stores a manuscript that arrived from another device.
  ///
  /// Separate from [saveStudio] for one reason: applying must never look like
  /// authoring. This writes the manuscript and updates the shadow to match, so
  /// the scenes just received are not immediately queued straight back — which
  /// is how two devices end up trading the same scene forever.
  Future<void> applyRemote(ManuscriptProjectSummary manuscript) async {
    await saveStudio(manuscript, persistLegacyText: false);
    await saveSyncShadow(
      manuscript.projectId,
      ManuscriptSyncShadow.of(manuscript),
    );
    // The outline too, not only the scenes. Updating one and not the other
    // would leave the structure looking freshly changed, so applying a remote
    // manuscript would immediately queue its outline straight back.
    await saveStructureFingerprint(
      manuscript.projectId,
      ManuscriptStructurePayload.of(manuscript).fingerprint,
    );
  }

  Future<void> saveStudio(
    ManuscriptProjectSummary manuscript, {
    bool persistLegacyText = true,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _studioKey(manuscript.projectId),
      jsonEncode(manuscript.toJson()),
    );

    if (persistLegacyText) {
      await preferences.setString(
        _key(manuscript.projectId),
        manuscript.exportAsSingleText(),
      );
    }

    final nodes = manuscriptNodesFor(manuscript);
    await _repository.putManuscriptNodes(nodes);

    // The projection is authoritative for its project, so saving it has to
    // retire what it no longer contains as well as write what it does. Without
    // this the projection is upsert-only: a chapter or scene removed from the
    // manuscript keeps its node, its links and its search-index entry for the
    // life of the database, and nothing can ever remove them.
    final projected = {for (final node in nodes) node.id};
    final retired = [
      for (final node
          in await _repository.manuscriptNodesForProject(manuscript.projectId))
        if (!projected.contains(node.id)) node.id,
    ];
    if (retired.isNotEmpty) {
      await _repository.removeManuscriptNodes(retired);
    }
  }

  /// The shared-entity projection of [manuscript].
  ///
  /// Chapters and scenes are already entities in the connected store, so this
  /// is how the manuscript participates in shared search, connections,
  /// inspection and history without a second record model. Scene and chapter
  /// body text is deliberately absent: prose stays in the manuscript store.
  static List<ManuscriptNodeReference> manuscriptNodesFor(
    ManuscriptProjectSummary manuscript,
  ) =>
      [
        for (final chapter in manuscript.chapters)
          manuscriptNodeForChapter(chapter, manuscript.projectId),
        for (final chapter in manuscript.chapters)
          for (final scene in chapter.scenes)
            manuscriptNodeForScene(scene, manuscript.projectId),
      ];

  static ManuscriptNodeReference manuscriptNodeForChapter(
    ManuscriptChapter chapter,
    String projectId,
  ) =>
      ManuscriptNodeReference(
        id: chapter.id,
        projectId: projectId,
        nodeType: 'chapter',
        title: chapter.title,
        createdAt: chapter.createdAt,
        updatedAt: chapter.updatedAt,
        extensionData: {
          'order': chapter.order,
          'status': chapter.status.id,
          'pov': chapter.pov,
          'summary': chapter.summary,
          'sceneCount': chapter.scenes.length,
          'wordCount': chapter.wordCount,
          'linkedChapterIds': chapter.linkedChapterIds,
        },
      );

  static ManuscriptNodeReference manuscriptNodeForScene(
    ManuscriptScene scene,
    String projectId,
  ) =>
      ManuscriptNodeReference(
        id: scene.id,
        projectId: projectId,
        nodeType: 'scene',
        title: scene.title,
        createdAt: scene.createdAt,
        updatedAt: scene.updatedAt,
        extensionData: {
          'chapterId': scene.chapterId,
          'order': scene.order,
          'status': scene.status.id,
          'pov': scene.pov,
          'location': scene.location,
          'timeLabel': scene.timeLabel,
          'notes': scene.notes,
          'wordCount': scene.wordCount,
        },
      );

  Future<ManuscriptProjectSummary> _migrateLegacyToStudio(
    String projectId, {
    required String manuscriptTitle,
    required List<ManuscriptChapterSeed> defaultChapters,
    required String firstSceneTitle,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final legacyText = preferences.getString(_key(projectId)) ?? '';
    if (legacyText.trim().isNotEmpty) {
      await preferences.setString(_legacyBackupKey(projectId), legacyText);
    }

    final chapterSeeds = defaultChapters.isEmpty
        ? const [ManuscriptChapterSeed(title: 'Chapter 01')]
        : defaultChapters;
    final now = DateTime.now();
    final chapters = <ManuscriptChapter>[];

    for (var chapterIndex = 0;
        chapterIndex < chapterSeeds.length;
        chapterIndex++) {
      final chapterSeed = chapterSeeds[chapterIndex];
      final chapterId = ManuscriptId.create('chapter');
      final sceneTitles =
          chapterSeed.scenes.isEmpty ? ['Scene 01'] : chapterSeed.scenes;
      final scenes = <ManuscriptScene>[];
      for (var sceneIndex = 0; sceneIndex < sceneTitles.length; sceneIndex++) {
        final seededTitle = sceneTitles[sceneIndex].trim().isEmpty
            ? 'Scene ${(sceneIndex + 1).toString().padLeft(2, '0')}'
            : sceneTitles[sceneIndex].trim();
        final sceneTitle = chapterIndex == 0 &&
                sceneIndex == 0 &&
                firstSceneTitle.trim().isNotEmpty
            ? firstSceneTitle.trim()
            : seededTitle;
        scenes.add(
          ManuscriptScene(
            id: ManuscriptId.create('scene'),
            chapterId: chapterId,
            title: sceneTitle,
            order: sceneIndex + 1,
            content: chapterIndex == 0 && sceneIndex == 0 ? legacyText : '',
            status: _statusFromLegacy(chapterSeed.status),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      chapters.add(
        ManuscriptChapter(
          id: chapterId,
          title: chapterSeed.title.trim().isEmpty
              ? 'Chapter ${(chapterIndex + 1).toString().padLeft(2, '0')}'
              : chapterSeed.title.trim(),
          order: chapterIndex + 1,
          status: _statusFromLegacy(chapterSeed.status),
          prompt: chapterSeed.prompt,
          linkedChapterIds: chapterSeed.linkedChapterIds,
          scenes: scenes,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final currentChapterId = chapters.isEmpty ? '' : chapters.first.id;
    final currentSceneId = chapters.isEmpty || chapters.first.scenes.isEmpty
        ? ''
        : chapters.first.scenes.first.id;

    return ManuscriptProjectSummary(
      projectId: projectId,
      manuscriptTitle: manuscriptTitle,
      chapters: chapters,
      currentChapterId: currentChapterId,
      currentSceneId: currentSceneId,
      createdAt: now,
      updatedAt: now,
      version: 2,
      migration: {
        'source': legacyText.trim().isEmpty ? 'seed' : 'legacy_text',
        'migratedAt': now.toIso8601String(),
      },
    );
  }

  ManuscriptNodeStatus _statusFromLegacy(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'archived') {
      return ManuscriptNodeStatus.complete;
    }
    if (normalized == 'active') {
      return ManuscriptNodeStatus.draft;
    }
    return ManuscriptNodeStatusX.fromId(normalized);
  }
}
