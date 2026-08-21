import 'core/book_scope.dart';
import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/entity_recognition.dart';
import 'core/record_service.dart';
import 'core/story_codex_domain.dart';
import 'manuscript_store.dart';
import 'persistence/authoros_database.dart';

/// How confident AuthorOS is that a name in the prose is a known entity.
enum EntityRecognitionState {
  /// The author has already connected this entity to this scene, or explicitly
  /// confirmed the match.
  confirmed,

  /// Exactly one entity answers to this name and nothing connects them yet.
  suggested,

  /// The name resolves to more than one entity, or to none at all. AuthorOS
  /// will not pick for the author.
  unconfirmed,
}

/// What an author can do with a suggestion.
enum EntitySuggestionAction { link, ignore, createEntity, createAlias, review }

/// What a suggestion is anchored to.
enum EntityAnchorKind { scene, chapter }

/// One name found in the manuscript, and what AuthorOS thinks it means.
///
/// A suggestion is a **view-layer object**, never a stored relationship.
/// Producing one writes nothing; only an explicit author action does.
class EntitySuggestion {
  const EntitySuggestion({
    required this.anchorId,
    required this.anchorKind,
    required this.anchorTitle,
    required this.matchedName,
    required this.candidateIds,
    required this.state,
    required this.isAlias,
    required this.snippet,
    this.entityTitle = '',
    this.bookId,
  });

  final String anchorId;
  final EntityAnchorKind anchorKind;
  final String anchorTitle;

  /// The name exactly as the prose spells it.
  final String matchedName;

  /// Every entity the name could mean. Empty means no record answers to it.
  final List<String> candidateIds;

  final EntityRecognitionState state;
  final bool isAlias;

  /// The sentence the name was found in, so the author can judge in context.
  final String snippet;

  final String entityTitle;
  final String? bookId;

  /// The single entity this refers to, or null when that is not answerable.
  String? get entityId =>
      candidateIds.length == 1 ? candidateIds.single : null;

  bool get isAmbiguous => candidateIds.length > 1;
  bool get isUnknownName => candidateIds.isEmpty;

  /// A stable key for this suggestion, so a dismissal survives a rescan.
  ///
  /// Keyed on the anchor and the written name rather than on a match id: the
  /// author dismissed *this name in this scene*, and that judgement should hold
  /// even after the prose around it is rewritten.
  String get key => '$anchorId|${matchedName.toLowerCase()}';

  /// What the author can do about this suggestion.
  List<EntitySuggestionAction> get actions => switch (state) {
        EntityRecognitionState.confirmed => const [
            EntitySuggestionAction.review,
          ],
        EntityRecognitionState.suggested => const [
            EntitySuggestionAction.link,
            EntitySuggestionAction.ignore,
            EntitySuggestionAction.review,
          ],
        EntityRecognitionState.unconfirmed => isUnknownName
            ? const [
                EntitySuggestionAction.createEntity,
                EntitySuggestionAction.createAlias,
                EntitySuggestionAction.ignore,
                EntitySuggestionAction.review,
              ]
            : const [
                EntitySuggestionAction.link,
                EntitySuggestionAction.createAlias,
                EntitySuggestionAction.ignore,
                EntitySuggestionAction.review,
              ],
      };
}

/// Recognises entities named in manuscript prose, and never acts on its own.
///
/// The rule the directive is built around: **AuthorOS never silently rewrites
/// canon.** A scan reads prose and returns suggestions. It creates no record,
/// writes no link, and changes no field. Every mutation here is behind an
/// explicit method the author's action calls.
///
/// Recognition itself is deterministic — exact, case-insensitive, word-boundary
/// matching against titles and aliases the author wrote down. There is no
/// model, no scoring and no inference. A name that resolves to two entities is
/// reported as unconfirmed rather than guessed at.
class EntitySuggestionService {
  const EntitySuggestionService({
    required this.projectId,
    required this.repository,
    this.maxSuggestionsPerScene = 12,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  /// A ceiling so a long scene cannot flood the panel.
  final int maxSuggestionsPerScene;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  ConnectionEngine get connections =>
      ConnectionEngine(scopeId: projectId, repository: repository);

  /// The record holding this project's dismissals.
  String get dismissalRecordId => 'codex-suggestions-$projectId';

  // ------------------------------------------------------------- scanning --

  /// Every entity named in [scene] that the author has not already settled.
  ///
  /// Reads. Never writes.
  Future<List<EntitySuggestion>> forScene(
    ManuscriptProjectSummary manuscript,
    String sceneId,
  ) async {
    final located = _locate(manuscript, sceneId);
    if (located == null) return const [];
    final (chapter, scene) = located;
    return _suggestionsFor(
      anchorId: scene.id,
      anchorKind: EntityAnchorKind.scene,
      anchorTitle: scene.title,
      bookId: chapter.bookId,
      prose: [scene.title, scene.content, scene.notes, scene.timeLabel]
          .where((part) => part.trim().isNotEmpty)
          .join('\n'),
    );
  }

  /// Every entity named anywhere in [chapterId].
  Future<List<EntitySuggestion>> forChapter(
    ManuscriptProjectSummary manuscript,
    String chapterId,
  ) async {
    final chapter = manuscript.chapterById(chapterId);
    if (chapter == null) return const [];
    final suggestions = <EntitySuggestion>[];
    for (final scene in chapter.scenes) {
      suggestions.addAll(await forScene(manuscript, scene.id));
    }
    return suggestions;
  }

  /// Every entity named anywhere in [bookId], or in unfiled chapters when it
  /// is null.
  Future<List<EntitySuggestion>> forBook(
    ManuscriptProjectSummary manuscript,
    String? bookId,
  ) async {
    final suggestions = <EntitySuggestion>[];
    for (final chapter in manuscript.chapters) {
      if (chapter.bookId != bookId) continue;
      suggestions.addAll(await forChapter(manuscript, chapter.id));
    }
    return suggestions;
  }

  Future<List<EntitySuggestion>> _suggestionsFor({
    required String anchorId,
    required EntityAnchorKind anchorKind,
    required String anchorTitle,
    required String? bookId,
    required String prose,
  }) async {
    if (prose.trim().isEmpty) return const [];
    final all = await repository.recordsByProject(projectId);
    final candidates = all
        .where((record) => record.status == AuthorRecordStatus.active)
        .where((record) => !_isInfrastructure(record))
        // Book-specific entities are only recognised inside their own book, so
        // a Book 2 cameo is never suggested against a Book 1 scene.
        .where((record) => BookScope.visibleInBook(record, bookId))
        .toList();

    final index = EntityNameIndex.fromRecords(candidates);
    final mentions = index.scan(prose, limit: maxSuggestionsPerScene);
    if (mentions.isEmpty) return const [];

    final connected = <String>{
      for (final link in await repository.backlinks(anchorId))
        link.sourceId == anchorId ? link.targetId : link.sourceId,
    };
    final dismissed = await dismissedKeys();

    final suggestions = <EntitySuggestion>[];
    for (final mention in mentions) {
      final resolved = mention.entityId;
      final state = resolved != null && connected.contains(resolved)
          ? EntityRecognitionState.confirmed
          : mention.isAmbiguous
              ? EntityRecognitionState.unconfirmed
              : EntityRecognitionState.suggested;
      final suggestion = EntitySuggestion(
        anchorId: anchorId,
        anchorKind: anchorKind,
        anchorTitle: anchorTitle,
        matchedName: mention.matchedName,
        candidateIds: mention.entityIds,
        state: state,
        isAlias: mention.isAlias,
        entityTitle: mention.canonicalTitle,
        snippet: _snippet(prose, mention.start, mention.end),
        bookId: bookId,
      );
      // A dismissal only silences an open question. Something the author has
      // actually connected keeps showing as confirmed.
      if (state != EntityRecognitionState.confirmed &&
          dismissed.contains(suggestion.key)) {
        continue;
      }
      suggestions.add(suggestion);
    }
    return suggestions;
  }

  // -------------------------------------------------------------- actions --

  /// Connects the suggested entity to the scene or chapter it was found in.
  ///
  /// The link is stamped with its provenance, so a relationship AuthorOS
  /// proposed can always be told apart from one the author drew by hand.
  Future<RecordLink> link(
    EntitySuggestion suggestion, {
    String? entityId,
    String typeId = BookScope.appearsInTypeId,
    DateTime? timestamp,
  }) async {
    final target = entityId ?? suggestion.entityId;
    if (target == null) {
      throw StateError(
        'This name matches ${suggestion.candidateIds.length} entities. '
        'Choose one before linking.',
      );
    }
    return connections.connect(
      sourceId: target,
      targetId: suggestion.anchorId,
      typeId: typeId,
      // Provenance, per the connected-domain rule that a promoted derived
      // relationship must carry its derivation. A reader can always tell a
      // link AuthorOS proposed from one the author drew by hand — and the
      // author still had to accept it for this to be written at all.
      extensionData: {
        'derivedFrom': 'entityRecognition',
        'matchedName': suggestion.matchedName,
        if (suggestion.isAlias) 'matchedAlias': true,
      },
      timestamp: timestamp,
    );
  }

  /// Adds the written name to an entity's aliases, so it is recognised
  /// everywhere from now on.
  Future<AuthorRecord> createAlias(
    EntitySuggestion suggestion, {
    required String entityId,
    DateTime? timestamp,
  }) =>
      addAlias(entityId, suggestion.matchedName, timestamp: timestamp);

  /// Adds [alias] to [recordId]'s aliases.
  ///
  /// Goes through [RecordService] rather than writing the field directly, so
  /// the change is validated, versioned and audited like any other edit.
  Future<AuthorRecord> addAlias(
    String recordId,
    String alias, {
    DateTime? timestamp,
  }) async {
    final normalized = alias.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('An alias is required.');
    }
    final record = await records.getRecord(recordId);
    if (record == null) {
      throw StateError('Record $recordId does not exist in project $projectId.');
    }
    final existing = EntityNames.split(record.fields[CodexFields.aliases]);
    if (existing.any((each) => each.toLowerCase() == normalized.toLowerCase())) {
      return record;
    }
    return records.updateRecord(
      record.copyWith(
        fields: {
          ...record.fields,
          CodexFields.aliases: [...existing, normalized],
        },
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
    );
  }

  // ---------------------------------------------------------- dismissals --

  /// Every suggestion the author has dismissed in this project.
  Future<Set<String>> dismissedKeys() async {
    final record = await repository.recordById(dismissalRecordId);
    if (record == null) return const {};
    final stored = record.fields['dismissedKeys'];
    if (stored is! List) return const {};
    return {
      for (final key in stored)
        if (key.toString().trim().isNotEmpty) key.toString(),
    };
  }

  /// Dismisses [suggestion] so a rescan does not raise it again.
  ///
  /// Stored on a project-scoped infrastructure record, the way saved views and
  /// pins already are, and written straight to the repository rather than
  /// through [RecordService] — dismissing a suggestion is housekeeping, and it
  /// should not put a version snapshot and an audit event in the author's
  /// history for every click.
  Future<void> ignore(EntitySuggestion suggestion, {DateTime? timestamp}) =>
      _writeDismissals(
        (keys) => keys..add(suggestion.key),
        timestamp: timestamp,
      );

  /// Un-dismisses [suggestion], so it can be raised again.
  Future<void> restore(EntitySuggestion suggestion, {DateTime? timestamp}) =>
      _writeDismissals(
        (keys) => keys..remove(suggestion.key),
        timestamp: timestamp,
      );

  Future<void> clearDismissals({DateTime? timestamp}) =>
      _writeDismissals((keys) => keys..clear(), timestamp: timestamp);

  Future<void> _writeDismissals(
    Set<String> Function(Set<String>) change, {
    DateTime? timestamp,
  }) async {
    final now = (timestamp ?? DateTime.now()).toUtc();
    final existing = await repository.recordById(dismissalRecordId);
    final keys = change((await dismissedKeys()).toSet());
    final sorted = keys.toList()..sort();
    if (existing == null) {
      await repository.putRecord(
        AuthorRecord(
          id: dismissalRecordId,
          typeId: CodexInfrastructureTypes.suggestionState,
          scopeType: RecordScopeType.project,
          scopeId: projectId,
          projectId: projectId,
          title: 'Dismissed suggestions',
          fields: {'dismissedKeys': sorted},
          createdAt: now,
          updatedAt: now,
        ),
      );
      return;
    }
    await repository.putRecord(
      existing.copyWith(
        fields: {...existing.fields, 'dismissedKeys': sorted},
        revision: existing.revision + 1,
        updatedAt: now,
      ),
    );
  }

  // --------------------------------------------------------------- shared --

  (ManuscriptChapter, ManuscriptScene)? _locate(
    ManuscriptProjectSummary manuscript,
    String sceneId,
  ) {
    for (final chapter in manuscript.chapters) {
      for (final scene in chapter.scenes) {
        if (scene.id == sceneId) return (chapter, scene);
      }
    }
    return null;
  }

  bool _isInfrastructure(AuthorRecord record) =>
      CodexInfrastructureTypes.all.contains(record.typeId) ||
      record.typeId == BookScope.entityStateTypeId;
}

/// The sentence a name was found in, trimmed to something readable.
String _snippet(String prose, int start, int end) {
  const padding = 60;
  final from = (start - padding).clamp(0, prose.length);
  final to = (end + padding).clamp(0, prose.length);
  final text = prose.substring(from, to).replaceAll('\n', ' ').trim();
  return [
    if (from > 0) '…',
    text,
    if (to < prose.length) '…',
  ].join();
}
