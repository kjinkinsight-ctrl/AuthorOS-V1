import 'package:author_studio_v1/character_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';

class CharacterDomainFixture {
  CharacterDomainFixture(this.characters);

  final CharacterService characters;
  final DateTime timestamp = DateTime.utc(2026, 8, 20);

  Future<void> seed() async {
    await characters.createCharacter(
      id: 'kali',
      displayName: 'Kali Vale',
      templateId: 'character-main',
      canonStatus: CanonStatus.canon,
      tags: const ['protagonist', 'widow'],
      fields: const {
        'identity.aliases': ['Red Widow'],
        'identity.roles': ['Protagonist', 'POV Character'],
        'appearance.eyeColour': 'Grey',
        'personality.coreTraits': ['Resolute', 'Observant'],
        'psychology.coreWound': 'She failed to protect her sister.',
        'psychology.primaryMotivation': 'Protect her found family.',
        'backstory.childhood': 'Raised near the flooded gate.',
        'goals.entries': [
          {
            'goal': 'Expose the Widow Network',
            'type': 'Long-Term',
            'priority': 5,
            'status': 'Active',
          }
        ],
        'arcs.entries': [
          {
            'type': 'Belief Arc',
            'startingState': 'Trusts nobody',
            'endState': 'Chooses interdependence',
          }
        ],
        'secrets.entries': [
          {
            'secret': 'She opened the flooded gate.',
            'importance': 5,
            'revealStatus': 'Hidden',
          }
        ],
        'knowledge.entries': [
          {'subject': 'Iron Reliquary', 'state': 'Suspects'}
        ],
        'voice.speechStyle': 'Precise and guarded',
        'pov.enabled': true,
        'pov.narrativeReliability': 'Selective',
      },
      timestamp: timestamp,
    );
    await characters.createCharacter(
      id: 'cassian',
      displayName: 'Cassian Rook',
      templateId: 'character-supporting',
      fields: const {
        'identity.roles': ['Supporting Character']
      },
      timestamp: timestamp,
    );
    await characters.createCharacter(
      id: 'vincenzo',
      displayName: 'Vincenzo Vale',
      templateId: 'character-antagonist',
      fields: const {
        'identity.roles': ['Antagonist']
      },
      timestamp: timestamp,
    );
    await characters.createCharacter(
      id: 'lucia',
      displayName: 'Lucia North',
      templateId: 'character-love-interest',
      fields: const {
        'identity.roles': ['Love Interest']
      },
      timestamp: timestamp,
    );
    await characters.createCharacter(
      id: 'mara',
      displayName: 'Mara Voss',
      templateId: 'character-pov',
      fields: const {
        'identity.roles': ['POV Character'],
        'pov.enabled': true,
      },
      timestamp: timestamp,
    );

    for (final record in [
      _record('widow-network', 'faction', 'Widow Network'),
      _record('ashfall-harbor', 'location', 'Ashfall Harbor'),
      _record('widows-knife', 'item', "Widow's Knife"),
      _record('flooded-gate-secret', 'secret', 'The Flooded Gate Secret'),
      _record('widow-thread', 'plot-thread', 'Expose the Widow Network'),
      _record('scene-opening', 'scene', 'Opening Scene'),
      _record('event-betrayal', 'historical-event', 'The Betrayal'),
      _record('codex-reliquary', 'general-lore', 'The Iron Reliquary'),
    ]) {
      await characters.records.createRecord(record);
    }

    await characters.connectCharacter(
      characterId: 'kali',
      targetId: 'cassian',
      typeId: 'friendOf',
      direction: RecordLinkDirection.undirected,
      metadata: const {'status': 'Allies', 'trust': 4},
      timestamp: timestamp,
    );
    await characters.connectCharacter(
      characterId: 'kali',
      targetId: 'vincenzo',
      typeId: 'enemyOf',
      direction: RecordLinkDirection.undirected,
      metadata: const {'status': 'Enemies', 'conflict': 'Control of the gate'},
      timestamp: timestamp,
    );
    await characters.connectCharacter(
      characterId: 'kali',
      targetId: 'lucia',
      typeId: 'partnerOf',
      direction: RecordLinkDirection.undirected,
      metadata: const {'status': 'Secret', 'secret': true},
      timestamp: timestamp,
    );
    await characters.connectCharacter(
      characterId: 'kali',
      targetId: 'widow-network',
      typeId: 'memberOf',
      metadata: const {'rank': 'Red Widow', 'status': 'Active'},
      timestamp: timestamp,
    );
    await characters.connectCharacter(
      characterId: 'kali',
      targetId: 'ashfall-harbor',
      typeId: 'livesIn',
      timestamp: timestamp,
    );
    await characters.connectCharacter(
      characterId: 'kali',
      targetId: 'widows-knife',
      typeId: 'owns',
      timestamp: timestamp,
    );
    await characters.connectCharacter(
      characterId: 'kali',
      targetId: 'flooded-gate-secret',
      typeId: 'relatedTo',
      direction: RecordLinkDirection.undirected,
      timestamp: timestamp,
    );
    await characters.connectCharacter(
      characterId: 'kali',
      targetId: 'widow-thread',
      typeId: 'pursues',
      timestamp: timestamp,
    );
    await characters.connectCharacter(
      characterId: 'kali',
      targetId: 'scene-opening',
      typeId: 'appearsIn',
      timestamp: timestamp,
    );
    await characters.connectCharacter(
      characterId: 'kali',
      targetId: 'codex-reliquary',
      typeId: 'knows',
      metadata: const {'knowledgeState': 'Suspects', 'private': true},
      timestamp: timestamp,
    );
    await characters.connections.connect(
      sourceId: 'event-betrayal',
      targetId: 'kali',
      typeId: 'involves',
      timestamp: timestamp,
    );
  }

  AuthorRecord _record(String id, String typeId, String title) => AuthorRecord(
        id: id,
        typeId: typeId,
        scopeType: RecordScopeType.project,
        scopeId: characters.projectId,
        projectId: characters.projectId,
        title: title,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
}
