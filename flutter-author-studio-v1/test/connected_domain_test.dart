import 'dart:convert';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/migrations/legacy_connection_slice.dart';
import 'package:author_studio_v1/release_destinations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 17);
  const character = StoryCodexEntry(
    id: 'character-ari',
    title: 'Ari Vale',
    type: StoryCodexType.character,
    aliases: ['Ari'],
    summary: 'A harbor cartographer.',
    tags: ['protagonist'],
    mentions: ['scene-opening'],
  );

  ManuscriptScene scene() => ManuscriptScene(
        id: 'scene-opening',
        chapterId: 'chapter-1',
        title: 'The Message',
        order: 1,
        content: 'Ari unfolded the letter.',
        status: ManuscriptNodeStatus.draft,
        relationships: const [
          SceneRelationship(
            id: 'relationship-ari-opening',
            type: SceneRelationshipType.character,
            targetId: 'character-ari',
            label: 'POV character',
          ),
        ],
        createdAt: timestamp,
        updatedAt: timestamp,
      );

  test('legacy connection slice is disabled by default', () {
    expect(
      () => const LegacyConnectionSliceAdapter().migrateCharacterScene(
        projectId: 'project-1',
        character: character,
        scene: scene(),
      ),
      throwsStateError,
    );
  });

  test('legacy character and scene migrate to one typed canonical link', () {
    final snapshot =
        const LegacyConnectionSliceAdapter(enabled: true).migrateCharacterScene(
      projectId: 'project-1',
      character: character,
      scene: scene(),
    );

    expect(snapshot.records.single.id, 'character-ari');
    expect(snapshot.manuscriptNodes.single.id, 'scene-opening');
    expect(snapshot.links.single.id, 'relationship-ari-opening');
    expect(snapshot.links.single.typeId, 'appearsIn');
    expect(snapshot.links.single.sourceId, 'character-ari');
    expect(snapshot.links.single.targetId, 'scene-opening');
  });

  test('character and scene expose the same backlink', () {
    final snapshot =
        const LegacyConnectionSliceAdapter(enabled: true).migrateCharacterScene(
      projectId: 'project-1',
      character: character,
      scene: scene(),
    );
    final repository = InMemoryConnectedDomainRepository(initial: snapshot);

    expect(repository.backlinks('character-ari').single.id,
        'relationship-ari-opening');
    expect(repository.backlinks('scene-opening').single.id,
        'relationship-ari-opening');
  });

  test('snapshot JSON round trip preserves IDs and extension data', () {
    final migrated =
        const LegacyConnectionSliceAdapter(enabled: true).migrateCharacterScene(
      projectId: 'project-1',
      character: character,
      scene: scene(),
    );
    final encoded = jsonEncode(migrated.toJson());
    final restored = ConnectedDomainSnapshot.fromJson(
      Map<String, dynamic>.from(jsonDecode(encoded) as Map),
    );

    expect(restored.records.single.id, migrated.records.single.id);
    expect(
        restored.manuscriptNodes.single.id, migrated.manuscriptNodes.single.id);
    expect(restored.links.single.id, migrated.links.single.id);
    expect(restored.records.single.extensionData['legacySource'],
        'StoryCodexEntry');
  });

  test('failed transaction does not commit a dangling link', () {
    final repository = InMemoryConnectedDomainRepository();

    expect(
      () => repository.transaction((transaction) {
        transaction.putRecord(
          AuthorRecord(
            id: 'character-ari',
            typeId: 'character',
            scopeType: RecordScopeType.project,
            scopeId: 'project-1',
            title: 'Ari Vale',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        transaction.putLink(
          RecordLink(
            id: 'dangling-link',
            sourceId: 'character-ari',
            targetId: 'missing-scene',
            typeId: 'appearsIn',
            scopeId: 'project-1',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
      }),
      throwsStateError,
    );
    expect(repository.recordById('character-ari'), isNull);
    expect(repository.backlinks('character-ari'), isEmpty);
  });
}
