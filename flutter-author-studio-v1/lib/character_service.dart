import 'core/branch_service.dart';
import 'core/character_presentation.dart';
import 'core/character_record_types.dart';
import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/record_inspection.dart';
import 'core/record_inspector.dart';
import 'core/record_service.dart';
import 'core/record_types.dart';
import 'core/record_validation.dart';
import 'core/safe_delete.dart';
import 'core/safe_delete_service.dart';
import 'core/search_models.dart';
import 'core/template_engine.dart';
import 'core/universal_search.dart';
import 'core/version_audit.dart';
import 'core/version_audit_service.dart';
import 'persistence/authoros_database.dart';

class CharacterService {
  const CharacterService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

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

  Future<AuthorRecord> createCharacter({
    required String id,
    required String displayName,
    Map<String, Object?> fields = const {},
    List<String> tags = const [],
    String templateId = 'character-basic',
    int templateVersion = 1,
    RecordScopeType scopeType = RecordScopeType.project,
    String? scopeId,
    String? seriesId,
    String? bookId,
    String? branchId,
    CanonStatus canonStatus = CanonStatus.draft,
    DateTime? timestamp,
  }) async {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'is required');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final character = AuthorRecord(
      id: id,
      typeId: 'character',
      scopeType: scopeType,
      scopeId: scopeId ?? projectId,
      projectId: projectId,
      seriesId: seriesId,
      bookId: bookId,
      branchId: branchId,
      canonStatus: canonStatus,
      title: normalizedName,
      schemaVersion: CharacterRecordTypes.character.templateVersion,
      templateId: templateId,
      templateVersion: templateVersion,
      fields: {
        'identity.displayName': normalizedName,
        'identity.fullName': normalizedName,
        ...fields,
      },
      tags: tags,
      createdAt: now,
      updatedAt: now,
      extensionData: const {'characterStudio': true},
    );
    if (scopeType == RecordScopeType.branch) {
      if (branchId == null || scopeId != branchId) {
        throw StateError(
          'Branch-created characters require a matching branch and scope id.',
        );
      }
      await branches.createRecord(branchId, character, timestamp: now);
      return character;
    }
    return records.createRecord(character);
  }

  Future<AuthorRecord?> getCharacter(String id) async {
    final record = await records.getRecord(id);
    return record?.typeId == 'character' ? record : null;
  }

  Future<AuthorRecord> updateCharacter(
    AuthorRecord character, {
    AuditChangeType? changeType,
    String? summary,
  }) {
    _requireCharacter(character);
    return records.updateRecord(
      character,
      changeType: changeType,
      summary: summary,
    );
  }

  Future<AuthorRecord> duplicateCharacter(
    String id, {
    required String newId,
    String? title,
    DateTime? timestamp,
  }) async {
    await _requireCharacterId(id);
    return records.duplicateRecord(
      id,
      newId: newId,
      title: title,
      timestamp: timestamp,
    );
  }

  Future<AuthorRecord> archiveCharacter(String id,
      {DateTime? timestamp}) async {
    await _requireCharacterId(id);
    return records.archiveRecord(id, timestamp: timestamp);
  }

  Future<AuthorRecord> restoreCharacter(String id,
      {DateTime? timestamp}) async {
    await _requireCharacterId(id);
    return records.restoreRecord(id, timestamp: timestamp);
  }

  Future<SafeDeleteAnalysis?> analyzeDelete(String id) async {
    await _requireCharacterId(id);
    return safeDelete.analyze(id);
  }

  Future<AuthorRecord> softDeleteCharacter(
    String id, {
    DateTime? timestamp,
  }) async {
    final analysis = await analyzeDelete(id);
    if (analysis == null ||
        analysis.disposition == SafeDeleteDisposition.blocked) {
      throw StateError('Character $id has dependencies and cannot be deleted.');
    }
    return records.deleteRecord(id, timestamp: timestamp);
  }

  Future<RecordLink> connectCharacter({
    required String characterId,
    required String targetId,
    required String typeId,
    String label = '',
    RecordLinkDirection direction = RecordLinkDirection.directed,
    Map<String, Object?> metadata = const {},
    DateTime? timestamp,
  }) async {
    await _requireCharacterId(characterId);
    return connections.connect(
      sourceId: characterId,
      targetId: targetId,
      typeId: typeId,
      label: label,
      direction: direction,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  Future<RecordLink> updateCharacterConnection(
    String characterId,
    String linkId, {
    String? typeId,
    String? label,
    Map<String, Object?>? metadata,
    DateTime? timestamp,
  }) async {
    await _requireCharacterId(characterId);
    final links = await connections.connections(characterId);
    if (!links.any((link) => link.id == linkId)) {
      throw StateError('Connection $linkId does not belong to $characterId.');
    }
    return connections.updateConnection(
      linkId,
      typeId: typeId,
      label: label,
      metadata: metadata,
      timestamp: timestamp,
    );
  }

  Future<void> removeCharacterConnection(
    String characterId,
    String linkId, {
    DateTime? timestamp,
  }) async {
    await _requireCharacterId(characterId);
    final links = await connections.connections(characterId);
    if (!links.any((link) => link.id == linkId)) {
      throw StateError('Connection $linkId does not belong to $characterId.');
    }
    return connections.disconnect(linkId, timestamp: timestamp);
  }

  Future<List<RecordLink>> getCharacterConnections(String id) async {
    await _requireCharacterId(id);
    return connections.connections(id);
  }

  Future<List<RecordLink>> getCharacterRelationships(String id) =>
      _linksOfTypes(id, const {
        'relatedTo',
        'parentOf',
        'guardianOf',
        'friendOf',
        'enemyOf',
        'alliedWith',
        'rivalOf',
        'mentors',
        'partnerOf',
        'knows'
      });

  Future<List<RecordLink>> getCharacterScenes(String id) =>
      _linksOfTypes(id, const {'appearsIn', 'mentionedIn'});

  Future<List<RecordLink>> getCharacterTimeline(String id) =>
      _linksOfTypes(id, const {'involves', 'bornIn'});

  Future<List<RecordLink>> getCharacterLocations(String id) =>
      _linksOfTypes(id, const {'livesIn', 'bornIn', 'worksIn', 'visits'});

  Future<List<RecordLink>> getCharacterFactions(String id) =>
      _linksOfTypes(id, const {'memberOf'});

  Future<List<RecordLink>> getCharacterItems(String id) =>
      _linksOfTypes(id, const {'owns', 'uses', 'carries'});

  Future<List<RecordLink>> getCharacterThreads(String id) =>
      _linksOfTypes(id, const {'pursues', 'hasArc', 'relatedTo'});

  Future<List<SearchResult>> searchCharacters(String query) =>
      search.searchByType(query, 'character');

  Future<RecordValidationResult> validateCharacter(
    AuthorRecord character,
  ) async {
    _requireCharacter(character);
    return records.validateRecord(character);
  }

  Future<TemplateCompatibilityReport> inspectTemplate(
    AuthorRecord character,
  ) async {
    _requireCharacter(character);
    return TemplateEngine(await records.registry()).inspect(character);
  }

  Future<CharacterPresentationModel> presentationFor(
    AuthorRecord character,
  ) async {
    _requireCharacter(character);
    return CharacterPresentationModel.fromRecord(
      character,
      await records.registry(),
    );
  }

  Future<UniversalRecordInspection?> inspectCharacter(
    String id, {
    String? branchId,
  }) async {
    await _requireCharacterId(id);
    return inspector.inspectRecord(id,
        recordType: 'character', branchId: branchId);
  }

  Future<List<RecordVersion>> getCharacterHistory(
    String id, {
    String? branchId,
  }) async {
    await _requireCharacterId(id);
    return history.getVersionHistory(recordId: id, branchId: branchId);
  }

  Future<void> overrideCharacterInBranch(
    String branchId,
    String characterId, {
    String? title,
    Map<String, Object?> fields = const {},
    List<String> removedFieldIds = const [],
    List<String>? tags,
    CanonStatus? canonStatus,
    DateTime? timestamp,
  }) async {
    await _requireCharacterId(characterId);
    return branches.overrideRecord(
      branchId,
      characterId,
      title: title,
      fields: fields,
      removedFieldIds: removedFieldIds,
      tags: tags,
      canonStatus: canonStatus,
      timestamp: timestamp,
    );
  }

  Future<void> registerCustomTemplate(RecordTypeDefinition template) {
    if (template.baseTypeId != 'character' ||
        template.scopeType != RecordScopeType.project ||
        template.scopeId != projectId) {
      throw StateError(
        'Custom character templates must extend character in $projectId.',
      );
    }
    return repository.putRecordTypeDefinition(template);
  }

  Future<List<RecordLink>> _linksOfTypes(
    String id,
    Set<String> typeIds,
  ) async {
    final links = await getCharacterConnections(id);
    return links.where((link) => typeIds.contains(link.typeId)).toList();
  }

  Future<AuthorRecord> _requireCharacterId(String id) async {
    final character = await getCharacter(id);
    if (character == null) {
      throw StateError('$id is not a character in $projectId.');
    }
    return character;
  }

  void _requireCharacter(AuthorRecord record) {
    if (record.typeId != 'character' ||
        (record.projectId ?? record.scopeId) != projectId) {
      throw StateError('${record.id} is not a character in $projectId.');
    }
  }
}
