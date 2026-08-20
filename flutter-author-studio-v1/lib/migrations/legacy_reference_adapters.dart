import '../manuscript_store.dart';
import '../release_destinations.dart';
import '../timeline.dart';
import '../visual_planning.dart';
import 'legacy_reference_models.dart';

class LegacyReferenceAdapters {
  const LegacyReferenceAdapters._();

  static List<LegacyReference> storyCodex(StoryCodexEntry entry) => [
        for (final relationship in entry.relationships.entries)
          LegacyReference(
            id: 'codex:${entry.id}:relationship:${relationship.key}',
            legacyReference: relationship.value,
            source: 'StoryCodexEntry.relationships',
            sourceEntityId: entry.id,
            fieldPath: 'relationships.${relationship.key}',
            expectedRecordTypes: _codexRelationshipTypes(relationship.key),
            reason: 'Legacy Codex relationship stores a target name.',
          ),
        for (var index = 0; index < entry.mentions.length; index++)
          LegacyReference(
            id: 'codex:${entry.id}:mention:$index',
            legacyReference: entry.mentions[index],
            source: 'StoryCodexEntry.mentions',
            sourceEntityId: entry.id,
            fieldPath: 'mentions[$index]',
            stableRecordId: entry.mentions[index],
            expectedRecordTypes: const ['scene', 'chapter', 'historical-event'],
            reason: 'Legacy Codex mention is intended to contain a stable ID.',
          ),
      ];

  static List<LegacyReference> manuscriptScene(ManuscriptScene scene) => [
        if (_usableName(scene.pov))
          LegacyReference(
            id: 'scene:${scene.id}:pov',
            legacyReference: scene.pov,
            source: 'ManuscriptScene.pov',
            sourceEntityId: scene.id,
            fieldPath: 'pov',
            expectedRecordTypes: const ['character'],
            reason: 'Manuscript POV stores a character name.',
          ),
        if (_usableName(scene.location))
          LegacyReference(
            id: 'scene:${scene.id}:location',
            legacyReference: scene.location,
            source: 'ManuscriptScene.location',
            sourceEntityId: scene.id,
            fieldPath: 'location',
            expectedRecordTypes: const ['location', 'place'],
            reason: 'Manuscript location stores a location name.',
          ),
        for (var index = 0; index < scene.relationships.length; index++)
          LegacyReference(
            id: 'scene:${scene.id}:relationship:$index',
            legacyReference: scene.relationships[index].targetId,
            source: 'SceneRelationship.targetId',
            sourceEntityId: scene.id,
            fieldPath: 'relationships[$index].targetId',
            stableRecordId: scene.relationships[index].targetId,
            expectedRecordTypes:
                _sceneRelationshipTypes(scene.relationships[index].type),
            reason:
                'Scene relationship target is intended to contain a stable ID.',
          ),
      ];

  static List<LegacyReference> timelineEvent(TimelineEvent event) => [
        if (_usableName(event.pov))
          LegacyReference(
            id: 'timeline:${event.id}:pov',
            legacyReference: event.pov,
            source: 'TimelineEvent.pov',
            sourceEntityId: event.id,
            fieldPath: 'pov',
            expectedRecordTypes: const ['character'],
            reason: 'Timeline POV stores a character name.',
          ),
        for (var index = 0; index < event.presentCharacters.length; index++)
          if (_usableName(event.presentCharacters[index]))
            LegacyReference(
              id: 'timeline:${event.id}:presentCharacter:$index',
              legacyReference: event.presentCharacters[index],
              source: 'TimelineEvent.presentCharacters',
              sourceEntityId: event.id,
              fieldPath: 'presentCharacters[$index]',
              expectedRecordTypes: const ['character'],
              reason: 'Timeline participants store character names.',
            ),
        if (_usableName(event.location))
          LegacyReference(
            id: 'timeline:${event.id}:location',
            legacyReference: event.location,
            source: 'TimelineEvent.location',
            sourceEntityId: event.id,
            fieldPath: 'location',
            expectedRecordTypes: const ['location', 'place'],
            reason: 'Timeline location stores a location name.',
          ),
        if (_usableName(event.plotline))
          LegacyReference(
            id: 'timeline:${event.id}:plotline',
            legacyReference: event.plotline,
            source: 'TimelineEvent.plotline',
            sourceEntityId: event.id,
            fieldPath: 'plotline',
            expectedRecordTypes: const ['plot-thread'],
            reason: 'Timeline plotline stores a plot thread name.',
          ),
      ];

  static List<LegacyReference> planningScene(PlanningScene scene) => [
        if (_usableName(scene.pov))
          LegacyReference(
            id: 'planning:${scene.id}:pov',
            legacyReference: scene.pov,
            source: 'PlanningScene.pov',
            sourceEntityId: scene.id,
            fieldPath: 'pov',
            expectedRecordTypes: const ['character'],
            reason: 'Visual Planning POV stores a character name.',
          ),
      ];
}

List<String> _codexRelationshipTypes(String relationship) =>
    switch (relationship.toLowerCase()) {
      'mentor' || 'rival' || 'owner' => const ['character', 'faction'],
      'capital' || 'linked_location' => const ['location', 'place'],
      _ => const [],
    };

List<String> _sceneRelationshipTypes(SceneRelationshipType type) =>
    switch (type) {
      SceneRelationshipType.character => const ['character'],
      SceneRelationshipType.location => const ['location', 'place'],
      SceneRelationshipType.plotPoint => const ['plot-thread'],
      SceneRelationshipType.timelineEvent => const [
          'historical-event',
          'timeline-event'
        ],
      SceneRelationshipType.previousScene ||
      SceneRelationshipType.nextScene ||
      SceneRelationshipType.relatedScene =>
        const ['scene'],
      SceneRelationshipType.researchItem => const [
          'research-entry',
          'reference'
        ],
      SceneRelationshipType.note => const ['author-note'],
    };

bool _usableName(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isNotEmpty &&
      normalized != 'unassigned' &&
      normalized != 'none';
}
