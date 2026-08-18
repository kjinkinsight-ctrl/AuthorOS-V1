import '../core/connected_domain.dart';
import '../manuscript_store.dart';
import '../release_destinations.dart';

class LegacyConnectionSliceAdapter {
  const LegacyConnectionSliceAdapter({
    this.enabled = AuthorOsFeatureFlags.connectedDomain,
  });

  final bool enabled;

  ConnectedDomainSnapshot migrateCharacterScene({
    required String projectId,
    required StoryCodexEntry character,
    required ManuscriptScene scene,
  }) {
    if (!enabled) {
      throw StateError('The connected-domain migration slice is disabled.');
    }
    if (character.type != StoryCodexType.character) {
      throw ArgumentError.value(
        character.type,
        'character',
        'The migration slice requires a character Codex entry.',
      );
    }
    if (projectId.trim().isEmpty ||
        character.id.trim().isEmpty ||
        scene.id.trim().isEmpty) {
      throw const FormatException(
        'Project, character, and scene IDs are required.',
      );
    }

    final repository = InMemoryConnectedDomainRepository();
    repository.transaction((transaction) {
      transaction.putRecord(
        AuthorRecord(
          id: character.id,
          typeId: StoryCodexType.character.name,
          scopeType: RecordScopeType.project,
          scopeId: projectId,
          title: character.title,
          status: character.isArchived
              ? AuthorRecordStatus.archived
              : AuthorRecordStatus.active,
          fields: {
            'aliases': character.aliases,
            'summary': character.summary,
            'legacyRelationships': character.relationships,
            'legacyMentions': character.mentions,
          },
          tags: character.tags,
          createdAt: scene.createdAt,
          updatedAt: scene.updatedAt,
          extensionData: const {'legacySource': 'StoryCodexEntry'},
        ),
      );
      transaction.putManuscriptNode(
        ManuscriptNodeReference(
          id: scene.id,
          projectId: projectId,
          nodeType: 'scene',
          title: scene.title,
          createdAt: scene.createdAt,
          updatedAt: scene.updatedAt,
          extensionData: {
            'chapterId': scene.chapterId,
            'legacyStatus': scene.status.name,
          },
        ),
      );
      transaction.putLink(
        RecordLink(
          id: _linkId(character, scene),
          sourceId: character.id,
          targetId: scene.id,
          typeId: 'appearsIn',
          scopeId: projectId,
          label: 'Appears in',
          metadata: _legacyRelationshipMetadata(character, scene),
          createdAt: scene.createdAt,
          updatedAt: scene.updatedAt,
          extensionData: const {'legacySource': 'SceneRelationship'},
        ),
      );
    });
    return repository.snapshot();
  }

  String _linkId(StoryCodexEntry character, ManuscriptScene scene) {
    for (final relationship in scene.relationships) {
      if (relationship.type == SceneRelationshipType.character &&
          relationship.targetId == character.id &&
          relationship.id.trim().isNotEmpty) {
        return relationship.id;
      }
    }
    return 'link_${character.id}_${scene.id}_appearsIn';
  }

  Map<String, Object?> _legacyRelationshipMetadata(
    StoryCodexEntry character,
    ManuscriptScene scene,
  ) {
    for (final relationship in scene.relationships) {
      if (relationship.type == SceneRelationshipType.character &&
          relationship.targetId == character.id) {
        return {
          'legacyType': relationship.type.name,
          'legacyLabel': relationship.label,
          'legacyMetadata': relationship.metadata,
        };
      }
    }
    return const {'inferredFrom': 'StoryCodexEntry.mentions'};
  }
}
